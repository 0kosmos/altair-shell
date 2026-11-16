// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.components
import qs.core
import qs.services
import qs.theme

// The dock: pinned apps, running apps and recent apps (services/DockApps.qml),
// one per screen. Off by default; when off, no window exists at all.
//
// The window is a transparent strip along its edge (full length, so the dock
// can grow and shrink smoothly inside it without the surface being resized
// every frame). Only the dock itself takes input (mask) and gets blur. Extra
// room on the inner side holds the hover zoom and the name tooltip.
//
// Auto-hide: the dock slides off the edge and the input region shrinks to a
// 3 px strip along that edge; touching it brings the dock back. While
// auto-hiding the dock never reserves space (windows would jump each time).
//
// Moving to another edge: the dock slides out at the old edge, the window is
// rebuilt (changing a live layer surface's anchors is unreliable) and the
// dock slides in at the new edge. Turning it on/off slides it too.
Scope {
    id: root

    readonly property string wantedPosition: ["left", "right"].indexOf(Config.dock.position) !== -1 ? Config.dock.position : "bottom"
    // The edge the current window is built for (lags behind during a move).
    property string position: wantedPosition
    readonly property bool vertical: position !== "bottom"
    readonly property int iconSize: Math.max(32, Math.min(64, Config.dock.iconSize || 44))
    readonly property int pad: 10
    readonly property int spacing: 6
    readonly property int cell: iconSize + spacing
    readonly property int thickness: iconSize + pad * 2
    readonly property int gap: Theme.barGap
    // Hover zoom (icons grow toward the screen's centre) + tooltip.
    readonly property real zoom: Theme.animations ? 1.22 : 1
    readonly property int headroom: Math.ceil(iconSize * 0.22) + 44
    readonly property bool autoHide: Config.dock.autoHide

    readonly property int slideIn: Theme.animations ? 420 : 0
    readonly property int slideOut: Theme.animations ? 300 : 0

    // ---- Lifecycle: built (window exists) / present (slid in) -----------------
    property bool built: DockApps.enabled
    property bool present: DockApps.enabled
    Connections {
        target: DockApps
        function onEnabledChanged() {
            if (DockApps.enabled) {
                swap.stop();
                root.position = root.wantedPosition;
                root.built = true;
                root.present = true;
            } else {
                root.present = false;
                swap.restart();
            }
        }
    }
    onWantedPositionChanged: {
        if (!built) {
            position = wantedPosition;
            return;
        }
        present = false;
        swap.restart();
    }
    // After the slide-out: unload (turned off) or rebuild at the new edge.
    Timer {
        id: swap
        interval: root.slideOut + 40
        onTriggered: {
            root.built = false;
            if (DockApps.enabled) {
                root.position = root.wantedPosition;
                Qt.callLater(() => {
                    root.built = DockApps.enabled;
                    root.present = DockApps.enabled;
                });
            }
        }
    }

    Variants {
        model: Quickshell.screens

        Scope {
            id: per
            required property var modelData

            LazyLoader {
                active: root.built

                PanelWindow {
                    id: win
                    screen: per.modelData

                    WlrLayershell.namespace: "altair-dock"
                    WlrLayershell.layer: WlrLayer.Top
                    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
                    color: "transparent"

                    // A vertical dock needs both top and bottom anchors, or the
                    // surface ends up 1 px long and reserves nothing.
                    anchors {
                        bottom: true
                        left: root.position !== "right"
                        right: root.position !== "left"
                        top: root.vertical
                    }
                    // Along the edge the anchors stretch it over the free length.
                    implicitWidth: root.vertical ? root.gap + root.thickness + root.headroom : 0
                    implicitHeight: root.vertical ? 0 : root.gap + root.thickness + root.headroom

                    // Reserve the dock (not the zoom/tooltip room). 0 = reserve
                    // nothing but still stack next to the bar if it shares the edge.
                    exclusionMode: ExclusionMode.Normal
                    exclusiveZone: Config.dock.reserveSpace && !root.autoHide ? root.gap + root.thickness : 0

                    mask: Region { item: body.shown ? body : trigger }

                    // Always the same Region object: switching it on and off
                    // made Hyprland blur the whole surface for a frame when
                    // the dock came back. Off-screen parts are clipped anyway.
                    BackgroundEffect.blurRegion: Theme.blur ? blurShape : null
                    Region {
                        id: blurShape
                        item: body
                        radius: Theme.radius.l
                    }

                    // ---- Auto-hide ---------------------------------------------
                    // Pointer over the dock (or the trigger strip): the input
                    // region is limited by the mask, so the whole surface works.
                    HoverHandler {
                        id: hover
                    }
                    property bool menuOpen: false
                    readonly property bool wantShown: root.present && !Widgets.editing
                        && (!root.autoHide || hover.hovered || menuOpen || body.dragKey !== "" || DockApps.peeking)
                    onWantShownChanged: {
                        if (wantShown) {
                            hideDelay.stop();
                            body.shown = true;
                        } else {
                            hideDelay.interval = root.present && !Widgets.editing ? 500 : 0;
                            hideDelay.restart();
                        }
                    }
                    Timer {
                        id: hideDelay
                        onTriggered: body.shown = win.wantShown
                    }

                    // Whole edge: easy to hit without aiming.
                    Item {
                        id: trigger
                        width: root.vertical ? 3 : win.width
                        height: root.vertical ? win.height : 3
                        x: root.position === "right" ? win.width - width : 0
                        y: root.vertical ? 0 : win.height - height
                    }

                    // ---- The dock ------------------------------------------------
                    Item {
                        id: body

                        // Starts hidden and slides in once the window exists.
                        property bool shown: false
                        Component.onCompleted: Qt.callLater(() => body.shown = win.wantShown)

                        // 1 = in place, 0 = slid off the edge.
                        property real reveal: shown ? 1 : 0
                        Behavior on reveal {
                            NumberAnimation {
                                duration: body.shown ? root.slideIn : root.slideOut
                                easing.type: body.shown ? Easing.OutQuint : Easing.InCubic
                            }
                        }
                        readonly property real offset: (1 - reveal) * (root.gap + root.thickness + 8)
                        visible: reveal > 0

                        // Along-axis length, animated as apps come and go.
                        readonly property int targetLength: {
                            const n = DockApps.items.length;
                            const content = lead + n * root.cell - (lead + n > 0 ? root.spacing : 0);
                            return root.pad * 2 + Math.max(content, root.iconSize) + (sep1Shown ? sepSize : 0) + (sep2Shown ? sepSize : 0);
                        }
                        property int length: targetLength
                        Behavior on length {
                            NumberAnimation { duration: Theme.anim.slow; easing.type: Easing.OutQuint }
                        }

                        width: root.vertical ? root.thickness : length
                        height: root.vertical ? length : root.thickness
                        x: root.position === "bottom" ? Math.round((win.width - width) / 2)
                            : root.position === "left" ? root.gap - offset
                            : win.width - root.gap - width + offset
                        y: root.vertical ? Math.round((win.height - height) / 2) : win.height - root.gap - height + offset

                        // ---- Slots and drag-to-reorder ---------------------------
                        // Items sit in slots: launcher button, pinned apps,
                        // separator, running apps, separator, recent apps.
                        // While an app is dragged the others move aside to show
                        // where it will land.
                        property string dragKey: ""
                        property int dragFrom: -1
                        property real dragPos: 0          // dragged icon's centre, along the axis
                        property real dragOrigin: 0       // ... where the drag started
                        readonly property int pinnedCount: DockApps.pinnedCount
                        readonly property int lead: Config.dock.launcherButton ? root.cell : 0
                        readonly property int sepSize: 12
                        readonly property int dragTarget: {
                            if (dragKey === "")
                                return -1;
                            const raw = Math.round((dragPos - root.pad - lead - root.iconSize / 2) / root.cell);
                            const P = pinnedCount;
                            if (dragFrom < P)
                                return Math.max(0, Math.min(P - 1, raw));
                            // An unpinned app: pinned when dropped among the
                            // pinned ones (or at the very start if none are).
                            const pinnedEnd = root.pad + lead + (P > 0 ? P * root.cell : root.iconSize * 0.3);
                            return dragPos < pinnedEnd ? Math.max(0, Math.min(P, raw)) : dragFrom;
                        }
                        // Group sizes while dragging an unpinned app into the pinned ones.
                        readonly property bool pinning: dragFrom >= pinnedCount && dragTarget !== -1 && dragTarget <= pinnedCount && dragTarget !== dragFrom
                        readonly property bool dragRecent: dragFrom >= 0 && (DockApps.items[dragFrom]?.recent ?? false)
                        readonly property int effPinned: pinnedCount + (pinning ? 1 : 0)
                        readonly property int effRunning: DockApps.runningCount - (pinning && !dragRecent ? 1 : 0)
                        readonly property int effRecent: DockApps.recentShown - (pinning && dragRecent ? 1 : 0)
                        // pinned | running | recent, a line between non-empty groups.
                        readonly property bool sep1Shown: effPinned > 0 && effRunning + effRecent > 0
                        readonly property bool sep2Shown: effRunning > 0 && effRecent > 0
                        readonly property int b1: effPinned
                        readonly property int b2: effPinned + effRunning

                        function displayIndex(i: int): int {
                            const a = dragFrom, t = dragTarget;
                            if (dragKey === "" || t === -1 || i === a)
                                return i;
                            if (a < t && i > a && i <= t)
                                return i - 1;
                            if (t < a && i >= t && i < a)
                                return i + 1;
                            return i;
                        }
                        function slotPos(i: int): real {
                            return root.pad + lead + i * root.cell
                                + (sep1Shown && i >= b1 ? sepSize : 0)
                                + (sep2Shown && i >= b2 ? sepSize : 0);
                        }

                        function drop(): void {
                            const item = DockApps.items[dragFrom];
                            const t = dragTarget;
                            if (item?.entry && t !== -1 && t !== dragFrom) {
                                if (item.pinned)
                                    DockApps.move(item.key, t);
                                else
                                    DockApps.pin(item.key, t);
                            }
                            dragKey = "";
                            dragFrom = -1;
                        }

                        GlassBackground {
                            anchors.fill: parent
                            radius: Theme.radius.l
                        }

                        // Thin lines between the groups.
                        Repeater {
                            model: [{ shown: body.sep1Shown, at: body.b1 }, { shown: body.sep2Shown, at: body.b2 }]
                            Rectangle {
                                required property var modelData
                                opacity: modelData.shown ? 1 : 0
                                Behavior on opacity { NumberAnimation { duration: Theme.anim.fast } }
                                color: Theme.border
                                width: root.vertical ? root.iconSize * 0.6 : 1
                                height: root.vertical ? 1 : root.iconSize * 0.6
                                readonly property real along: body.slotPos(modelData.at) - body.sepSize / 2 - root.spacing / 2
                                x: root.vertical ? (parent.width - width) / 2 : along
                                y: root.vertical ? along : (parent.height - height) / 2
                                Behavior on x { enabled: !root.vertical; NumberAnimation { duration: Theme.anim.slow; easing.type: Easing.OutQuint } }
                                Behavior on y { enabled: root.vertical; NumberAnimation { duration: Theme.anim.slow; easing.type: Easing.OutQuint } }
                            }
                        }

                        // App grid button: opens the launcher.
                        Loader {
                            active: Config.dock.launcherButton
                            x: root.pad
                            y: root.pad
                            sourceComponent: MouseArea {
                                id: grid
                                width: root.iconSize
                                height: root.iconSize
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: ShellState.toggle("launcher")
                                scale: pressed ? Theme.anim.pressScale : 1
                                Behavior on scale { NumberAnimation { duration: Theme.anim.fast; easing.type: Easing.OutBack; easing.overshoot: 2.5 } }
                                Rectangle {
                                    anchors.fill: parent
                                    radius: Theme.radius.m
                                    color: grid.pressed ? Theme.pressed : grid.containsMouse ? Theme.hover : "transparent"
                                    Behavior on color { ColorAnimation { duration: Theme.anim.fast } }
                                }
                                Icon {
                                    anchors.centerIn: parent
                                    name: "apps"
                                    size: Math.round(root.iconSize * 0.6)
                                    color: ShellState.openPanel === "launcher" ? Theme.accent : Theme.fg
                                }
                            }
                        }

                        Repeater {
                            model: ScriptModel {
                                values: DockApps.items
                                objectProp: "key"
                            }

                            DockItem {
                                id: di
                                required property var modelData
                                readonly property int idx: DockApps.items.findIndex(i => i.key === modelData.key)
                                item: idx >= 0 ? DockApps.items[idx] : modelData

                                iconSize: root.iconSize
                                zoom: root.zoom
                                position: root.position
                                dragging: body.dragKey === item.key
                                busy: body.dragKey !== "" || win.menuOpen

                                readonly property real along: dragging ? body.dragPos - root.iconSize / 2 : body.slotPos(body.displayIndex(idx))
                                x: root.vertical ? root.pad : along
                                y: root.vertical ? along : root.pad
                                Behavior on x { enabled: !root.vertical && !di.dragging; NumberAnimation { duration: Theme.anim.slow; easing.type: Easing.OutQuint } }
                                Behavior on y { enabled: root.vertical && !di.dragging; NumberAnimation { duration: Theme.anim.slow; easing.type: Easing.OutQuint } }

                                onDragStarted: {
                                    body.dragFrom = idx;
                                    body.dragOrigin = along + root.iconSize / 2;
                                    body.dragPos = body.dragOrigin;
                                    body.dragKey = item.key;
                                }
                                onDragMoved: delta => {
                                    const min = root.pad + body.lead + root.iconSize / 2;
                                    const max = body.length - root.pad - root.iconSize / 2;
                                    body.dragPos = Math.max(min, Math.min(max, body.dragOrigin + delta));
                                }
                                onDragEnded: body.drop()
                                onMenuRequested: {
                                    menuLoader.target = di;
                                    menuLoader.active = true;
                                    win.menuOpen = true;
                                }
                            }
                        }
                    }

                    LazyLoader {
                        id: menuLoader
                        property var target: null
                        active: false

                        DockMenu {
                            anchorItem: menuLoader.target
                            item: menuLoader.target?.item ?? null
                            position: root.position
                            onDismissed: {
                                win.menuOpen = false;
                                menuLoader.active = false;
                            }
                        }
                    }
                }
            }
        }
    }
}
