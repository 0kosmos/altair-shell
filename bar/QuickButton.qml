// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import qs.components
import qs.core
import qs.theme

// Opens quick settings (quick/QuickSettings.qml). Settings > Bar can hide it.
BarButton {
    visible: Config.bar.quickSettings
    onClicked: ShellState.toggle("quick")

    Icon {
        name: "tune"
        color: ShellState.openPanel === "quick" ? Theme.accent : Theme.fg
    }
}
