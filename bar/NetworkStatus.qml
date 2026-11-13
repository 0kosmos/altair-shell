// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import qs.components
import qs.services
import qs.theme

// Connection type / Wi-Fi strength, dimmed when there is no internet access.
// Display only for now; network details and switching come with the dashboard.
BarButton {
    interactive: false

    Icon {
        name: Network.icon
        color: Network.kind === "none" || Network.limited ? Theme.fgDisabled : Theme.fg
    }
}
