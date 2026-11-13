// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Layouts
import qs.components
import qs.theme

// Base for a settings page: a scrollable column with a title. Put SettingRows,
// Sections, etc. inside as children.
Flickable {
    id: root

    property string title
    default property alias content: column.data

    contentHeight: column.implicitHeight + Theme.space.xl * 2
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    ColumnLayout {
        id: column
        x: Theme.space.xl
        y: Theme.space.xl
        width: root.width - Theme.space.xl * 2
        spacing: Theme.space.l

        StyledText {
            Layout.fillWidth: true
            Layout.bottomMargin: Theme.space.xs
            text: root.title
            font.pixelSize: Theme.font.title + 4
            font.weight: Font.DemiBold
        }
    }
}
