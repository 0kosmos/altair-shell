// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import qs.theme

// Text with the theme's font, size and colour.
Text {
    property bool tabular: false   // fixed-width digits, for numbers that change

    color: Theme.fg
    font.family: Theme.font.family
    font.pixelSize: Theme.font.body
    font.features: tabular ? { "tnum": 1 } : {}
    verticalAlignment: Text.AlignVCenter
    elide: Text.ElideRight

    Behavior on color {
        ColorAnimation { duration: Theme.anim.fast }
    }
}
