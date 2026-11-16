// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import qs.components
import qs.services
import qs.theme

// What dragging the bar will do (drawn inside the bar's window while it
// covers the screen, see Bar.qml): the screen dims a little, a ghost bar
// glides to the edge it would go to, and the dock's outline shows where the
// dock ends up (DockApps.rects already follow the previewed edge; widgets
// glide on their own).
Item {
    id: root

    property string target: "top"
    property string screenName: ""

    readonly property bool vertical: target === "left" || target === "right"
    readonly property int g: Theme.barGap
    readonly property int t: Theme.barThickness

    // Dim.
    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: root.visible ? 0.22 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.anim.normal; easing.type: Easing.OutCubic } }
    }

    // Ghost bar at the target edge.
    Item {
        id: ghost
        x: root.target === "right" ? root.width - root.g - root.t : root.g
        y: root.target === "bottom" ? root.height - root.g - root.t : root.g
        width: root.vertical ? root.t : root.width - root.g * 2
        height: root.vertical ? root.height - root.g * 2 : root.t
        Behavior on x { NumberAnimation { duration: Theme.anim.slow; easing.type: Easing.OutQuint } }
        Behavior on y { NumberAnimation { duration: Theme.anim.slow; easing.type: Easing.OutQuint } }
        Behavior on width { NumberAnimation { duration: Theme.anim.slow; easing.type: Easing.OutQuint } }
        Behavior on height { NumberAnimation { duration: Theme.anim.slow; easing.type: Easing.OutQuint } }

        GlassBackground {
            anchors.fill: parent
            radius: Theme.radius.m
            solidity: 0.5
        }
        Rectangle {
            anchors.fill: parent
            radius: Theme.radius.m
            color: Qt.alpha(Theme.accent, 0.12)
            border.width: 2
            border.color: Theme.accent
        }
    }

    // Where the dock will be.
    Rectangle {
        readonly property var r: DockApps.rects[root.screenName] ?? null
        visible: r !== null
        x: r?.x ?? 0
        y: r?.y ?? 0
        width: r?.w ?? 0
        height: r?.h ?? 0
        radius: Theme.radius.l
        color: Qt.alpha(Theme.fg, 0.06)
        border.width: 2
        border.color: Qt.alpha(Theme.fg, 0.45)
        Behavior on x { NumberAnimation { duration: Theme.anim.slow; easing.type: Easing.OutQuint } }
        Behavior on y { NumberAnimation { duration: Theme.anim.slow; easing.type: Easing.OutQuint } }
        Behavior on width { NumberAnimation { duration: Theme.anim.slow; easing.type: Easing.OutQuint } }
        Behavior on height { NumberAnimation { duration: Theme.anim.slow; easing.type: Easing.OutQuint } }
    }

    // Hint next to the ghost, inside the screen.
    Rectangle {
        readonly property int off: root.g + root.t + 16
        width: hint.implicitWidth + 28
        height: 34
        radius: 17
        color: Theme.base
        border.width: 1
        border.color: Theme.border
        x: root.target === "left" ? off : root.target === "right" ? root.width - off - width : (root.width - width) / 2
        y: root.target === "top" ? off : root.target === "bottom" ? root.height - off - height : (root.height - height) / 2
        Behavior on x { NumberAnimation { duration: Theme.anim.slow; easing.type: Easing.OutQuint } }
        Behavior on y { NumberAnimation { duration: Theme.anim.slow; easing.type: Easing.OutQuint } }
        StyledText {
            id: hint
            anchors.centerIn: parent
            text: root.target === Theme.barPosition ? "Release to keep the bar here" : "Release to move the bar to the " + root.target
            font.pixelSize: Theme.font.small + 1
        }
    }
}
