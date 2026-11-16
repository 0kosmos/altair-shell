// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import qs.theme

// One row of an Altair menu (tray menus, the dock's app menu): optional
// checkbox, Material icon or image icon, label, submenu chevron.
MouseArea {
    id: menuRow

    property string label
    property string iconSource
    property string iconName
    property bool checkable: false
    property bool checked: false
    property bool hasChildren: false

    Layout.fillWidth: true
    implicitHeight: 32
    hoverEnabled: true
    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor

    Rectangle {
        anchors.fill: parent
        radius: Theme.radius.s
        color: menuRow.enabled && menuRow.containsMouse ? Theme.hover : "transparent"
        Behavior on color {
            ColorAnimation { duration: Theme.anim.fast }
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.space.s
        anchors.rightMargin: Theme.space.s
        spacing: Theme.space.s

        Icon {
            visible: menuRow.checkable
            name: menuRow.checked ? "check_box" : "check_box_outline_blank"
            fill: menuRow.checked ? 1 : 0
            color: menuRow.checked ? Theme.accent : Theme.fgMuted
            size: 16
        }
        Icon {
            visible: menuRow.iconName !== ""
            name: menuRow.iconName
            size: 16
        }
        IconImage {
            visible: menuRow.iconSource !== "" && !menuRow.checkable
            source: menuRow.iconSource
            implicitSize: 16
        }
        StyledText {
            Layout.fillWidth: true
            text: menuRow.label.replace(/_(?!_)/g, "")   // strip mnemonic underscores
            color: menuRow.enabled ? Theme.fg : Theme.fgDisabled
        }
        Icon {
            visible: menuRow.hasChildren
            name: "chevron_right"
            size: 16
            color: Theme.fgMuted
        }
    }
}
