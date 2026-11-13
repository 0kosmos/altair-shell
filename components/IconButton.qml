// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import qs.theme

// A round, hoverable icon button.
MouseArea {
    id: root

    property string icon
    property int size: 28
    property int iconSize: 18
    property color color: Theme.fgMuted
    property real fill: 0

    implicitWidth: size
    implicitHeight: size
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: root.pressed ? Theme.pressed : root.containsMouse ? Theme.hover : "transparent"
        Behavior on color {
            ColorAnimation { duration: Theme.anim.fast }
        }
    }

    Icon {
        anchors.centerIn: parent
        name: root.icon
        size: root.iconSize
        fill: root.fill
        color: root.containsMouse ? Theme.fg : root.color
    }
}
