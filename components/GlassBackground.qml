// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import qs.theme

// The background of every Altair surface (bar, panels, popups, menus, Settings).
//
// Normal: a translucent rounded rectangle with a hairline border.
// Liquid glass (Theme.liquidGlass): a static shader adds a gradient tint,
// specular rim, inner glow and depth — see shaders/glass.frag for what is
// drawn and what is not possible. Only the active variant is created.
Item {
    id: root

    property real radius: Theme.radius.m
    property color color: Theme.surface
    property bool bordered: true
    // 0 = normal translucency, 1 = opaque. Text-heavy surfaces (Settings) use
    // a higher value so the background doesn't hurt readability.
    property real solidity: 0

    function solid(v: vector4d): vector4d {
        return Qt.vector4d(v.x, v.y, v.z, v.w + (1 - v.w) * solidity);
    }

    Rectangle {
        anchors.fill: parent
        visible: !Theme.liquidGlass
        radius: root.radius
        color: Qt.alpha(root.color, root.color.a + (1 - root.color.a) * root.solidity)
        border.width: root.bordered ? 1 : 0
        border.color: Theme.border

        Behavior on color {
            ColorAnimation { duration: Theme.anim.normal }
        }
    }

    Loader {
        anchors.fill: parent
        active: Theme.liquidGlass

        sourceComponent: ShaderEffect {
            readonly property size size: Qt.size(width, height)
            readonly property real radius: root.radius
            readonly property real rimStrength: Theme.glassRim
            readonly property vector4d topTint: root.solid(Theme.glassTop)
            readonly property vector4d bottomTint: root.solid(Theme.glassBottom)

            fragmentShader: Qt.resolvedUrl("../shaders/glass.frag.qsb")
        }
    }
}
