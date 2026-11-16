// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Layouts
import Quickshell.Services.SystemTray
import qs.theme

// System tray (StatusNotifierItem). Empty and zero-size when no app uses it.
// A row, or a column on a vertical bar.
GridLayout {
    id: root

    flow: Theme.barVertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
    rows: Theme.barVertical ? -1 : 1
    columns: Theme.barVertical ? 1 : -1
    rowSpacing: 0
    columnSpacing: 0
    visible: SystemTray.items.values.length > 0

    Repeater {
        model: SystemTray.items

        TrayItem {
            required property SystemTrayItem modelData
            item: modelData
        }
    }
}
