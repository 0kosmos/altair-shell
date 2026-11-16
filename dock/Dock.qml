// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.components
import qs.core
import qs.services
import qs.theme

// The dock: pinned apps + running apps (services/DockApps.qml), one per screen.
// Off by default; when off, no window exists at all.
//
// The window is a transparent strip along its edge (full length, so the dock
// can grow and shrink smoothly inside it without the surface being resized
// every frame). Only the dock itself takes input (mask) and gets blur. Extra
// room on the inner side holds the hover zoom and the name tooltip.
//
// Auto-hide: the dock slides off the edge and the input region shrinks to a
// 3 px strip there; touching it brings the dock back. While auto-hiding the
// dock never reserves space (windows would jump each time it shows).
Scope {
    id: root

    readonly property string position: ["left", "right"].indexOf(Config.dock.position) !== -1 ? Config.dock.position : "bottom"
    readonly property bool vertical: position !== "bottom"
    readonly property int iconSize: Math.max(32, Math.min(64, Config.dock.iconSize || 44))
    readonly property int pad: Theme.space.s
    readonly property int spacing: 6
    readonly property int cell: iconSize + spacing
    readonly property int thickness: iconSize + pad * 2
    readonly property int gap: Theme.barGap
    // Hover zoom (icons grow toward the screen's centre) + tooltip.
    readonly property real zoom: Theme.animations ? 1.2 : 1
    readonly property int headroom: Math.ceil(iconSize * 0.2) + 40
    readonly property bool autoHide: Config.dock.autoHide

    Variants {
        model: Quickshell.screens

        Scope {
            id: per
            required property var modelData

            // Changing a layer surface's anchors while it exists leaves it
            // 1 px long here, so a new position builds a new window.
            property string builtFor: root.position
            Connections {
                target: root
                function onPositionChanged() {
                    per.builtFor = "";
                    Qt.callLater(() => per.builtFor = root.position);
                }
            }

            LazyLoader {
                active: DockApps.enabled && per.builtFor === root.position

                PanelWindow {
                    id: win
                    screen: per.modelData

                    WlrLayershell.namespace: "altair-dock"
                    WlrLayershell.layer: WlrLayer.Top
                    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
                    color: "transparent"

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

                    BackgroundEffect.blurRegion: Theme.blur && body.reveal > 0 ? blurShape : null
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
                    readonly property bool wantShown: !Widgets.editing
                        && (!root.autoHide || hover.hovered || menuOpen || body.dragKey !== "")
                    onWantShownChanged: {
                        if (wantShown) {
                            hideDelay.stop();
                            body.shown = true;
                        } else {
                            hideDelay.restart();
                        }
                    }
                    Timer {
                        id: hideDelay
                        interval: Widgets.editing ? 0 : 450
                        onTriggered: body.shown = win.wantShown
                    }

                    Item {
                        id: trigger
                        width: root.vertical ? 3 : body.width
                        height: root.vertical ? body.height : 3
                        x: root.position === "right" ? win.width - width : root.vertical ? 0 : body.x
                        y: root.vertical ? body.y : win.height - height
                    }

                    // ---- The dock ------------------------------------------------
                    Item {
                        id: body

                        property bool shown: win.wantShown
                        // 1 = in place, 0 = slid off the edge.
                        property real reveal: shown ? 1 : 0
                        Behavior on reveal {
                            NumberAnimation {
                                duration: Theme.anim.normal
                                easing.type: body.shown ? Theme.anim.easingSlide : Theme.anim.easingIn
                            }
                        }
                        readonly property real offset: (1 - reveal) * (root.gap + root.thickness + 6)

                        // Along-axis length, animated as apps come and go.
                        readonly property int targetLength: {
                            const n = DockApps.items.length;
                            const lead = Config.dock.launcherButton ? root.cell : 0;
                            const content = lead + n * root.cell - (lead + n > 0 ? root.spacing : 0);
                            return root.pad * 2 + Math.max(content, root.iconSize) + (sepShown ? sepSize : 0);
                        }
                        property int length: targetLength
                        Behavior on length {
                            NumberAnimation { duration: Theme.anim.normal; easing.type: Theme.anim.easing }
                        }

                        width: root.vertical ? root.thickness : length
                        height: root.vertical ? length : root.thickness
                        x: root.position === "bottom" ? Math.round((win.width - width) / 2)
                            : root.position === "left" ? root.gap - offset
                            : win.width - root.gap - width + offset
                        y: root.vertical ? Math.round((win.height - height) / 2) : win.height - root.gap - height + offset
                        opacity: reveal > 0 ? 1 : 0

                        // ---- Slots and drag-to-reorder ---------------------------
                        // Items sit in slots: launcher button, pinned apps,
                        // separator, other running apps. While an app is dragged
                        // the others move aside to show where it will land.
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
                            // A running, unpinned app: pinned when dropped among
                            // the pinned ones (or at the very start if none are).
                            const pinnedEnd = root.pad + lead + (P > 0 ? P * root.cell : root.iconSize * 0.3);
                            return dragPos < pinnedEnd ? Math.max(0, Math.min(P, raw)) : dragFrom;
                        }
                        // Pinned slots while dragging an unpinned app into them.
                        readonly property int effPinned: pinnedCount + (dragFrom >= pinnedCount && dragTarget !== -1 && dragTarget <= pinnedCount && dragTarget !== dragFrom ? 1 : 0)
                        readonly property bool sepShown: effPinned > 0 && DockApps.items.length > effPinned

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
                            return root.pad + lead + i * root.cell + (sepShown && i >= effPinned ? sepSize : 0);
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

                        // Thin line between pinned and other running apps.
                        Rectangle {
                            visible: body.sepShown
                            color: Theme.border
                            width: root.vertical ? root.iconSize * 0.6 : 1
                            height: root.vertical ? 1 : root.iconSize * 0.6
                            readonly property real along: body.slotPos(body.effPinned) - body.sepSize / 2 - root.spacing / 2
                            x: root.vertical ? (parent.width - width) / 2 : along
                            y: root.vertical ? along : (parent.height - height) / 2
                            Behavior on x { enabled: !root.vertical; NumberAnimation { duration: Theme.anim.normal; easing.type: Theme.anim.easing } }
                            Behavior on y { enabled: root.vertical; NumberAnimation { duration: Theme.anim.normal; easing.type: Theme.anim.easing } }
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
                                Behavior on x { enabled: !root.vertical && !di.dragging; NumberAnimation { duration: Theme.anim.normal; easing.type: Theme.anim.easing } }
                                Behavior on y { enabled: root.vertical && !di.dragging; NumberAnimation { duration: Theme.anim.normal; easing.type: Theme.anim.easing } }

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
