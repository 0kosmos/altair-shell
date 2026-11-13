// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import qs.components
import qs.core
import qs.theme

// Gear: opens or closes Altair Settings.
BarButton {
    onClicked: ShellState.toggle("settings")

    Icon {
        name: "settings"
        fill: ShellState.settingsOpen ? 1 : 0
        // A quarter turn when Settings opens.
        rotation: ShellState.settingsOpen ? 90 : 0
        Behavior on rotation {
            NumberAnimation { duration: Theme.anim.slow; easing.type: Theme.anim.easingSlide }
        }
    }
}
