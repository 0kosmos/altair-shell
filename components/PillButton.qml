// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import qs.theme

// A small rounded text button (notification actions, "Clear all", ...).
MouseArea {
    id: root

    property string text

    implicitWidth: label.implicitWidth + Theme.space.m * 2
    implicitHeight: 28
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.pressed ? Theme.pressed : root.containsMouse ? Theme.hover : Theme.surfaceRaised
        border.width: 1
        border.color: Theme.border
        Behavior on color {
            ColorAnimation { duration: Theme.anim.fast }
        }
    }

    StyledText {
        id: label
        anchors.centerIn: parent
        text: root.text
        font.pixelSize: Theme.font.small
        font.weight: Font.Medium
    }
}
