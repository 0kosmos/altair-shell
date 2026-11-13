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
    // Search row + a fixed number of result rows. A fixed height means the
    // window never resizes while typing (resizing a surface is costly).
    panelHeight: searchHeight + rows * rowHeight + Theme.space.s * 3

    content: Component {
        LauncherContent {
            rowHeight: launcher.rowHeight
            searchHeight: launcher.searchHeight
        }
    }
}
