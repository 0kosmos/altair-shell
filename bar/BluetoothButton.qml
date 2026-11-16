// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import qs.components
import qs.core
import qs.services
import qs.theme

// Bluetooth state; click for the Bluetooth menu. Hidden without an adapter
// (or with the bluetooth service stopped), or when turned off in Settings > Bar.
BarButton {
    visible: Bt.available && Config.bar.bluetooth
    onClicked: ShellState.toggle("bluetooth")

    Icon {
        name: Bt.icon
        color: ShellState.openPanel === "bluetooth" ? Theme.accent : Bt.enabled ? Theme.fg : Theme.fgDisabled
    }
}
