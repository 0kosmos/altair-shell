// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.components
import qs.theme

// One window in the Alt+Tab switcher: a still preview (captured once when the
// switcher opens, never live) or the app icon, and the title.
Item {
    id: root

    required property var toplevel        // HyprlandToplevel
    property bool selected: false
    property bool previews: true
    signal activated()

    readonly property string appClass: toplevel?.lastIpcObject?.class ?? ""
    readonly property var entry: appClass ? DesktopEntries.heuristicLookup(appClass) : null

    width: 216
    height: 176

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        // No hover-to-select: a resting mouse would change the selection the
        // moment the switcher appears under it.
        onClicked: root.activated()
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.space.s
        spacing: Theme.space.s

        // Preview area.
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Theme.radius.s
            color: Qt.alpha(Theme.fg, 0.05)
            clip: true

            // One frame, captured when the card is created (live: false).
            ScreencopyView {
                id: shot
                anchors.centerIn: parent
                visible: root.previews && hasContent
                captureSource: root.previews ? root.toplevel?.wayland ?? null : null
                live: false
                constraintSize: Qt.size(parent.width, parent.height)
            }

            // No preview (off, not captured yet, or not possible): the app icon.
            IconImage {
                anchors.centerIn: parent
                visible: !shot.visible
                implicitSize: 56
                source: Quickshell.iconPath(root.entry?.icon ?? root.appClass, "application-x-executable")
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.space.xs

            IconImage {
                implicitSize: 16
                source: Quickshell.iconPath(root.entry?.icon ?? root.appClass, "application-x-executable")
            }
            StyledText {
                Layout.fillWidth: true
                text: root.toplevel?.title || root.entry?.name || root.appClass
                font.pixelSize: Theme.font.small
                font.weight: root.selected ? Font.DemiBold : Font.Normal
                color: root.selected ? Theme.fg : Theme.fgMuted
            }
        }
    }
}
