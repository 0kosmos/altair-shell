// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Layouts
import Quickshell.Services.SystemTray

// System tray (StatusNotifierItem). Empty and zero-width when no app uses it.
RowLayout {
    id: root

    spacing: 0
    visible: SystemTray.items.values.length > 0

    Repeater {
        model: SystemTray.items

        TrayItem {
            required property SystemTrayItem modelData
            item: modelData
        }
    }
}
