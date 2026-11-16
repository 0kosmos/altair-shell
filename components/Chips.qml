// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Layouts
import qs.services
import qs.theme

// Pick one of many options as a wrapping row of small pills (for lists too
// long for Segmented). options: [{ label, value }]. Reports `selected(value)`;
// bind `current` (no pill is lit if it matches none).
Flow {
    id: root

    property var options: []
    property var current
    signal selected(var value)

    Layout.fillWidth: true
    spacing: 6

    Repeater {
        model: root.options

        MouseArea {
            id: chip
            required property var modelData
            readonly property bool on: root.current === modelData.value

            implicitWidth: label.implicitWidth + 24
            implicitHeight: 28
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                Sounds.click();
                root.selected(modelData.value);
            }

            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: chip.on ? Theme.accent : chip.containsMouse ? Theme.hover : Theme.pressed
                border.width: chip.on ? 0 : 1
                border.color: Theme.border
                Behavior on color {
                    ColorAnimation { duration: Theme.anim.fast }
                }
            }
            StyledText {
                id: label
                anchors.centerIn: parent
                text: chip.modelData.label
                color: chip.on ? Theme.onAccent : Theme.fg
                font.pixelSize: Theme.font.small + 1
                font.weight: Font.Medium
                scale: chip.pressed ? Theme.anim.pressScale : 1
                Behavior on scale {
                    NumberAnimation { duration: Theme.anim.fast; easing.type: Easing.OutBack; easing.overshoot: 2.5 }
                }
            }
        }
    }
}
