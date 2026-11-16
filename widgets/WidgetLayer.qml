// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.core
import qs.services
import qs.theme

// Desktop widgets: one transparent layer per monitor, above the wallpaper and
// below the windows. Only the widgets take clicks (the rest of the layer lets
// input through). Exists only on monitors that have widgets, or in edit mode.
//
// Edit mode (Widgets.editing; SUPER + D, or Settings > Widgets): the layer
// moves above the windows, the screen dims, widgets get handles, and the dock
// slides up on the focused monitor. Escape or "Done" leaves.
Scope {
    Variants {
        model: Quickshell.screens

        Scope {
            id: per
            required property var modelData
            readonly property var mine: Widgets.itemsOn(modelData.name)

            // The desktop on this monitor is covered when its workspace has a
            // tiled or fullscreen window (floating ones usually leave most of
            // it free). Covered widgets aren't "live": anything animated or
            // polled (spinning disc, visualizer, readings) pauses. Hyprland
            // keeps asking covered layers for frames, so this saves real CPU.
            readonly property bool covered: {
                if (Widgets.editing)
                    return false;
                const ws = Hyprland.monitorFor(modelData)?.activeWorkspace;
                return (ws?.toplevels?.values ?? []).some(t => t.lastIpcObject?.floating === false || (t.lastIpcObject?.fullscreen ?? 0) > 0);
            }
            // Window state in lastIpcObject only updates on a refresh.
            Connections {
                target: Hyprland
                function onRawEvent(event) {
                    if (["openwindow", "closewindow", "movewindowv2", "changefloatingmode", "fullscreen"].indexOf(event.name) !== -1)
                        Qt.callLater(Hyprland.refreshToplevels);
                }
            }

            // The bar or dock moved (or changed what it reserves): ask Hyprland
            // for the new free area once it has re-arranged, so widgets can
            // glide out of the way (WidgetFrame.area).
            Connections {
                target: Theme
                function onBarPositionChanged() { reserved.restart(); }
            }
            Connections {
                target: Config.dock
                function onEnabledChanged() { reserved.restart(); }
                function onPositionChanged() { reserved.restart(); }
                function onReserveSpaceChanged() { reserved.restart(); }
                function onAutoHideChanged() { reserved.restart(); }
                function onIconSizeChanged() { reserved.restart(); }
            }
            Timer {
                id: reserved
                interval: 900   // after the dock's slide-out/in rebuild
                onTriggered: Hyprland.refreshMonitors()
            }
            Component.onCompleted: Hyprland.refreshMonitors()

            // Kept a moment after leaving edit mode, for the fade-out.
            property bool lingering: false
            Connections {
                target: Widgets
                function onEditingChanged() {
                    if (!Widgets.editing) {
                        per.lingering = true;
                        linger.restart();
                    } else {
                        Hyprland.refreshMonitors();   // fresh reserved space for the dock area
                    }
                }
            }
            Timer {
                id: linger
                interval: Theme.anim.normal + 100
                onTriggered: per.lingering = false
            }

            LazyLoader {
                active: per.mine.length > 0 || Widgets.editing || per.lingering

                PanelWindow {
                    id: win
                    screen: per.modelData

                    WlrLayershell.namespace: "altair-widgets"
                    // Widgets' own font (StyledText picks it up).
                    property string textFamily: Theme.widgetFont
                    WlrLayershell.layer: Widgets.editing ? WlrLayer.Top : WlrLayer.Bottom
                    WlrLayershell.keyboardFocus: Widgets.editing ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
                    exclusionMode: ExclusionMode.Ignore
                    anchors { top: true; bottom: true; left: true; right: true }
                    color: "transparent"

                    readonly property var mon: Snap.monitorInfo(Hyprland.monitorFor(screen))
                    readonly property var frameList: {
                        const l = [];
                        for (let i = 0; i < frames.count; i++)
                            if (frames.itemAt(i))
                                l.push(frames.itemAt(i));
                        return l;
                    }

                    // Outside edit mode only the widgets take input; in edit
                    // mode the whole screen does (null = everything).
                    mask: Widgets.editing ? null : clickRegion
                    Region {
                        id: clickRegion
                        regions: win.frameList.map(f => f.region)
                    }
                    BackgroundEffect.blurRegion: Theme.blur ? clickRegion : null

                    // Edit mode: dim everything behind the widgets.
                    Rectangle {
                        anchors.fill: parent
                        color: Qt.rgba(0, 0, 0, Math.max(0.3, Theme.dragDim))
                        opacity: Widgets.editing ? 1 : 0
                        visible: opacity > 0
                        Behavior on opacity {
                            NumberAnimation { duration: Theme.anim.normal; easing.type: Theme.anim.easing }
                        }
                    }

                    FocusScope {
                        anchors.fill: parent
                        focus: true
                        Keys.onEscapePressed: Widgets.editing = false

                        Repeater {
                            id: frames
                            // ScriptModel keeps each widget's delegate while
                            // its data changes (no rebuild on every save).
                            model: ScriptModel {
                                values: per.mine
                                objectProp: "id"
                            }
                            delegate: WidgetFrame {
                                required property var modelData
                                itemId: modelData.id
                                mon: win.mon
                                live: !per.covered
                                siblings: win.frameList
                            }
                        }

                        EditDock {
                            readonly property var u: win.mon.usable
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: Theme.space.xl
                            visible: Widgets.editing || per.lingering
                            shown: Widgets.editing && Hyprland.focusedMonitor?.name === per.modelData.name
                            monitor: per.modelData.name
                            area: ({ x: u.x - win.mon.x, y: u.y - win.mon.y, w: u.w, h: u.h })
                        }
                    }
                }
            }
        }
    }
}
