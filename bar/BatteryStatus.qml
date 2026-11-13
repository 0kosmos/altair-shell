// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import qs.components
import qs.services
import qs.theme

// Battery level; hidden on machines without a battery.
BarButton {
    visible: Battery.present
    interactive: false

    Icon {
        name: Battery.icon
        color: Battery.low ? Theme.critical : Theme.fg
    }
    StyledText {
        text: Math.round(Battery.level * 100) + "%"
        color: Battery.low ? Theme.critical : Theme.fg
        font.pixelSize: Theme.font.small
        tabular: true
    }
}
