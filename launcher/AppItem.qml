// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.components
import qs.theme

// One result row: app icon, name, and a muted description.
MouseArea {
    id: root

    required property var entry
    property bool current: false

    // `screenPos` is the pointer position in screen coordinates. The list uses
    // it to tell real mouse movement from rows scrolling under a still pointer
    // (Qt reports both as hover movement).
    signal hovered(point screenPos)
    signal activated()
    signal menuRequested(point pos)

    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    onPositionChanged: mouse => hovered(mapToGlobal(mouse.x, mouse.y))
    onClicked: mouse => {
        if (mouse.button === Qt.RightButton)
            menuRequested(Qt.point(mouse.x, mouse.y));
        else
            activated();
    }

    IconImage {
        id: icon
        anchors.left: parent.left
        anchors.leftMargin: Theme.space.m
        anchors.verticalCenter: parent.verticalCenter
        implicitSize: 32
        // Falls back to a generic icon when the app's icon isn't in the theme.
        source: Quickshell.iconPath(root.entry.icon, "application-x-executable")
        asynchronous: true
    }

    Column {
        anchors.left: icon.right
        anchors.leftMargin: Theme.space.m
        anchors.right: parent.right
        anchors.rightMargin: Theme.space.m
        anchors.verticalCenter: parent.verticalCenter
        spacing: 1

        StyledText {
            width: parent.width
            text: root.entry.name
            font.weight: root.current ? Font.DemiBold : Font.Normal
        }
        StyledText {
            width: parent.width
            visible: text.length > 0
            text: root.entry.genericName || root.entry.comment
            color: Theme.fgMuted
            font.pixelSize: Theme.font.small
        }
    }
}
