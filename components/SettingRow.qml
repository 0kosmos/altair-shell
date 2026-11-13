// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Layouts
import qs.theme

// One setting: title + optional description on the left, the control on the
// right. Put the control inside as a child.
RowLayout {
    id: root

    property string title
    property string description
    default property alias control: slot.data

    Layout.fillWidth: true
    spacing: Theme.space.l

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 2

        StyledText {
            Layout.fillWidth: true
            text: root.title
        }
        StyledText {
            Layout.fillWidth: true
            visible: root.description !== ""
            text: root.description
            color: Theme.fgMuted
            font.pixelSize: Theme.font.small
            wrapMode: Text.Wrap
        }
    }

    Item {
        id: slot
        Layout.alignment: Qt.AlignVCenter
        implicitWidth: childrenRect.width
        implicitHeight: childrenRect.height
    }
}
