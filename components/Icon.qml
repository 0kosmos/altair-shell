// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import qs.theme

// A Material Symbols icon, addressed by name (the font uses ligatures, so the
// text "volume_up" renders as the volume icon). Names: https://fonts.google.com/icons
Text {
    id: root

    property string name
    property int size: Theme.font.icon
    // Variable-font FILL axis: 0 = outlined, 1 = filled. Animatable.
    property real fill: 0

    text: name
    color: Theme.fg
    font.family: Theme.font.icons
    font.pixelSize: size
    font.variableAxes: ({ "FILL": fill, "opsz": Math.max(20, Math.min(48, size)) })
    verticalAlignment: Text.AlignVCenter
    horizontalAlignment: Text.AlignHCenter

    Behavior on color {
        ColorAnimation { duration: Theme.anim.fast }
    }
}
