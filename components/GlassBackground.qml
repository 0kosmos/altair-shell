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
    // Strength of liquid glass's bright rim, 0–1. Lower on surfaces whose
    // corners the compositor cuts with a larger radius (Settings window):
    // there the rim is clipped at the corners and reads as a stray line.
    property real rim: 1
    // Sides joined to a neighbour (widget groups): square corners and no
    // edge there, so the surfaces read as one.
    property bool openTop: false
    property bool openRight: false
    property bool openBottom: false
    property bool openLeft: false
    readonly property bool anyOpen: openTop || openRight || openBottom || openLeft
    // Liquid glass tint over a whole group: this item's top inside the group
    // and the group's height (0 = just this item).
    property real tintOffset: 0
    property real tintSpan: 0

    function solid(v: vector4d): vector4d {
        return Qt.vector4d(v.x, v.y, v.z, v.w + (1 - v.w) * solidity);
    }

    Rectangle {
        anchors.fill: parent
        visible: !Theme.liquidGlass
        radius: root.radius
        topLeftRadius: root.openTop || root.openLeft ? 0 : root.radius
        topRightRadius: root.openTop || root.openRight ? 0 : root.radius
        bottomLeftRadius: root.openBottom || root.openLeft ? 0 : root.radius
        bottomRightRadius: root.openBottom || root.openRight ? 0 : root.radius
        color: Qt.alpha(root.color, root.color.a + (1 - root.color.a) * root.solidity)
        // (No border in a group: the seams would show as double lines.)
        border.width: root.bordered && !root.anyOpen ? 1 : 0
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
            readonly property real rimStrength: Theme.glassRim * root.rim
            readonly property vector4d rimColor: Theme.glassRimColor
            readonly property vector4d topTint: root.solid(Theme.glassTop)
            readonly property vector4d bottomTint: root.solid(Theme.glassBottom)
            readonly property vector4d open: Qt.vector4d(root.openTop ? 1 : 0, root.openRight ? 1 : 0, root.openBottom ? 1 : 0, root.openLeft ? 1 : 0)
            readonly property point tintRange: Qt.point(root.tintOffset, root.tintSpan)

            fragmentShader: Qt.resolvedUrl("../shaders/glass.frag.qsb")
        }
    }
}
