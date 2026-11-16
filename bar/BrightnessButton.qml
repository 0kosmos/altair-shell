// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import qs.components
import qs.core
import qs.services
import qs.theme

// Screen brightness, like the volume button: scroll to change (5 % steps),
// click for the brightness popup (display/BrightnessPanel.qml).
BarButton {
    visible: Config.display.barButton
    onClicked: ShellState.toggle("brightness")
    onStepped: dir => Display.changeBrightness(dir * 5)

    Icon {
        name: Display.icon
        color: ShellState.openPanel === "brightness" ? Theme.accent : Theme.fg
    }
    StyledText {
        visible: !Theme.barVertical
        text: Display.brightness + "%"
        font.pixelSize: Theme.font.small
        tabular: true
    }
}
