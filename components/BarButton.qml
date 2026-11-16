// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Layouts
import qs.theme

// A rounded, hoverable container for bar items. Children are laid out in a row
// (a column on a vertical bar) and the button sizes itself to them.
//
// `stepped(direction)` fires once per wheel notch (+1 up, -1 down). Touchpads
// send many small deltas; they are accumulated so one gesture ≈ one notch.
MouseArea {
    id: root

    default property alias content: row.data
    property alias spacing: row.spacing
    property int padding: Theme.space.s
    // false = display only: no hover/press highlight, normal cursor, no clicks.
    // Use it for items without an action so they don't look clickable.
    property bool interactive: true

    signal stepped(int direction)

    readonly property bool vertical: Theme.barVertical
    implicitWidth: vertical ? Theme.barThickness - Theme.space.xs * 2 : row.implicitWidth + padding * 2
    implicitHeight: vertical ? row.implicitHeight + padding * 2 : Theme.barHeight - Theme.space.xs * 2

    hoverEnabled: interactive
    acceptedButtons: interactive ? (Qt.LeftButton | Qt.RightButton | Qt.MiddleButton) : Qt.NoButton
    cursorShape: interactive ? Qt.PointingHandCursor : Qt.ArrowCursor

    // Press feedback: shrink slightly, spring back on release.
    scale: pressed ? Theme.anim.pressScale : 1
    Behavior on scale {
        NumberAnimation { duration: Theme.anim.fast; easing.type: Easing.OutBack; easing.overshoot: 2.5 }
    }

    property int wheelAccum: 0
    onWheel: wheel => {
        wheelAccum += wheel.angleDelta.y;
        while (Math.abs(wheelAccum) >= 120) {
            const dir = wheelAccum > 0 ? 1 : -1;
            wheelAccum -= dir * 120;
            stepped(dir);
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radius.s
        color: !root.interactive ? "transparent"
            : root.pressed ? Theme.pressed
            : root.containsMouse ? Theme.hover : "transparent"

        Behavior on color {
            ColorAnimation { duration: Theme.anim.fast }
        }
    }

    GridLayout {
        id: row
        anchors.centerIn: parent
        flow: root.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
        rows: root.vertical ? -1 : 1
        columns: root.vertical ? 1 : -1
        rowSpacing: spacing
        columnSpacing: spacing
        property real spacing: Theme.space.xs
    }
}
