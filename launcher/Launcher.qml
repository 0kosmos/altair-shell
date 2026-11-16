// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import qs.components
import qs.theme

// App launcher panel. Toggle: `qs -c altair ipc call panels toggle launcher`
// (bound to SUPER+Space by hypr/init.lua).
AltairPanel {
    id: launcher

    readonly property int rows: 7
    readonly property int rowHeight: 52
    readonly property int searchHeight: 52

    name: "launcher"
    panelWidth: 560
    // Search row + a fixed number of result rows. The window keeps this size
    // (resizing a surface is costly); the visible panel shrinks to the
    // results (fitContent).
    panelHeight: searchHeight + rows * rowHeight + Theme.space.s * 3 + 1
    fitContent: true

    content: Component {
        LauncherContent {
            rows: launcher.rows
            rowHeight: launcher.rowHeight
            searchHeight: launcher.searchHeight
        }
    }
}
