// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.components
import qs.core
import qs.theme

// While the bar is dragged (bar/Bar.qml): an outline where it would go, on
// the edge nearest the pointer, with a short hint. Exists only during a drag;
// takes no input.
Scope {
    LazyLoader {
        active: ShellState.barDragTarget !== ""

        PanelWindow {
            id: win
            screen: Quickshell.screens.find(s => s.name === ShellState.barDragScreen) ?? Quickshell.screens[0]
            WlrLayershell.namespace: "altair-bar-hint"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Ignore
            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"
            mask: Region {}

            readonly property string target: ShellState.barDragTarget || "top"
            readonly property bool vertical: target === "left" || target === "right"
            readonly property int g: Theme.barGap
            readonly property int t: Theme.barThickness

            Rectangle {
                id: ghost
                radius: Theme.radius.m
                color: Qt.alpha(Theme.accent, 0.18)
                border.width: 2
                border.color: Theme.accent
                x: win.target === "right" ? win.width - win.g - win.t : win.g
                y: win.target === "bottom" ? win.height - win.g - win.t : win.g
                width: win.vertical ? win.t : win.width - win.g * 2
                height: win.vertical ? win.height - win.g * 2 : win.t
                Behavior on x { NumberAnimation { duration: Theme.anim.normal; easing.type: Easing.OutQuint } }
                Behavior on y { NumberAnimation { duration: Theme.anim.normal; easing.type: Easing.OutQuint } }
                Behavior on width { NumberAnimation { duration: Theme.anim.normal; easing.type: Easing.OutQuint } }
                Behavior on height { NumberAnimation { duration: Theme.anim.normal; easing.type: Easing.OutQuint } }
                opacity: 0
                Component.onCompleted: opacity = 1
                Behavior on opacity { NumberAnimation { duration: Theme.anim.fast } }
            }

            // "Release to move the bar here", inside the screen next to the outline.
            Rectangle {
                readonly property int off: win.g + win.t + 14
                width: hint.implicitWidth + 24
                height: 30
                radius: 15
                color: Theme.base
                border.width: 1
                border.color: Theme.border
                x: win.target === "left" ? off : win.target === "right" ? win.width - off - width : (win.width - width) / 2
                y: win.target === "top" ? off : win.target === "bottom" ? win.height - off - height : (win.height - height) / 2
                Behavior on x { NumberAnimation { duration: Theme.anim.normal; easing.type: Easing.OutQuint } }
                Behavior on y { NumberAnimation { duration: Theme.anim.normal; easing.type: Easing.OutQuint } }
                StyledText {
                    id: hint
                    anchors.centerIn: parent
                    text: win.target === Theme.barPosition ? "Release to keep the bar here" : "Release to move the bar " + (win.target === "top" || win.target === "bottom" ? "to the " : "to the ") + win.target
                    font.pixelSize: Theme.font.small
                }
            }
        }
    }
}
