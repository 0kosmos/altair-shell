// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import qs.components
import qs.theme

// Clipboard history (SUPER + SHIFT + V, `qs -c altair ipc call panels toggle
// clipboard`). Opt-in: Settings > Clipboard. Built like the launcher.
AltairPanel {
    id: panel

    readonly property int rows: 7
    readonly property int rowHeight: 56
    readonly property int searchHeight: 52

    name: "clipboard"
    panelWidth: 600
    panelHeight: searchHeight + rows * rowHeight + Theme.space.s * 3 + 1
    fitContent: true

    content: Component {
        ClipboardContent {
            rows: panel.rows
            rowHeight: panel.rowHeight
            searchHeight: panel.searchHeight
        }
    }
}
