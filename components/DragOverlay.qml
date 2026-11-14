// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services
import qs.theme

// While something is dragged (Snap.dragging): dims the rest of the screen,
// with a rounded hole where the dragged thing is, and draws alignment guides
// (the monitor's centre lines faintly, the line being snapped to in the accent
// colour). Lets every click through. Created on drag start, destroyed after
// fading out: nothing exists or runs while no drag is happening.
Scope {
    id: root

    property bool loaded: false
    readonly property bool wanted: Snap.dragging
    onWantedChanged: if (wanted) loaded = true

    LazyLoader {
        active: root.loaded

        PanelWindow {
            id: win

            screen: Quickshell.screens.find(s => s.name === Snap.screenName) ?? Quickshell.screens[0]
            WlrLayershell.namespace: "altair-drag"
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Ignore
            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"
            // Empty input region: clicks and the drag itself go through.
            mask: Region {}

            // Global layout coordinates -> this window.
            readonly property real ox: Snap.monitor?.x ?? 0
            readonly property real oy: Snap.monitor?.y ?? 0

            Item {
                id: body
                anchors.fill: parent
                opacity: 0
                Component.onCompleted: opacity = Qt.binding(() => root.wanted ? 1 : 0)
                Behavior on opacity {
                    NumberAnimation { duration: Theme.anim.normal; easing.type: Theme.anim.easing }
                }
                onOpacityChanged: if (opacity === 0 && !root.wanted) root.loaded = false

                // Dim with a rounded hole: a rectangle around the dragged thing
                // whose (huge) border is the dim. Qt draws the inner edge with
                // radius - border.width, i.e. exactly the thing's own radius.
                Rectangle {
                    readonly property real b: Math.max(win.width, win.height) * 2
                    readonly property var r: Snap.rect
                    visible: r !== null
                    x: (r?.x ?? 0) - win.ox - b
                    y: (r?.y ?? 0) - win.oy - b
                    width: (r?.w ?? 0) + b * 2
                    height: (r?.h ?? 0) + b * 2
                    radius: Snap.radius + b
                    color: "transparent"
                    border.width: b
                    border.color: Qt.rgba(0, 0, 0, Theme.dragDim)
                }

                // Faint centre lines, always shown while dragging.
                Rectangle {
                    x: Math.round(win.width / 2)
                    width: 1
                    height: win.height
                    color: Qt.alpha(Theme.fg, 0.18)
                }
                Rectangle {
                    y: Math.round(win.height / 2)
                    height: 1
                    width: win.width
                    color: Qt.alpha(Theme.fg, 0.18)
                }

                // The lines being snapped to.
                Repeater {
                    model: Snap.guidesX
                    Rectangle {
                        required property real modelData
                        x: Math.round(modelData - win.ox) - 1
                        width: 2
                        height: win.height
                        color: Theme.accent
                    }
                }
                Repeater {
                    model: Snap.guidesY
                    Rectangle {
                        required property real modelData
                        y: Math.round(modelData - win.oy) - 1
                        height: 2
                        width: win.width
                        color: Theme.accent
                    }
                }
            }
        }
    }
}
