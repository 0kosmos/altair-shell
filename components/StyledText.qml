// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import Quickshell
import qs.theme

// Text with the theme's font, size and colour. A window can ask for another
// family with a `textFamily` property (the desktop widgets do: Settings >
// Appearance > Widget font); everything else uses the UI font.
Text {
    property bool tabular: false   // fixed-width digits, for numbers that change

    color: Theme.fg
    font.family: QsWindow.window?.textFamily || Theme.font.family
    font.pixelSize: Theme.font.body
    font.features: tabular ? { "tnum": 1 } : {}
    verticalAlignment: Text.AlignVCenter
    elide: Text.ElideRight

    Behavior on color {
        ColorAnimation { duration: Theme.anim.fast }
    }
}
