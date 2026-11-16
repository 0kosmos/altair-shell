// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import qs.components
import qs.core
import qs.services
import qs.theme

// Connection type / Wi-Fi strength, dimmed when there is no internet access.
// Click: the network menu (connections/NetworkPanel.qml).
BarButton {
    onClicked: ShellState.toggle("network")

    Icon {
        name: Network.icon
        color: ShellState.openPanel === "network" ? Theme.accent
            : Network.kind === "none" || Network.limited ? Theme.fgDisabled : Theme.fg
    }
}
