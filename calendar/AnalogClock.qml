// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import Quickshell
import qs.theme

// A round analogue clock: minute marks, hour/minute hands, an optional
// seconds hand in the accent colour. Reusable (calendar popup, desktop widget).
//
// Cost: its own SystemClock ticks once a minute, or once a second with the
// seconds hand — only while this item exists. Hands are plain rotated
// rectangles; the face is static. The hands jump, like a quartz clock: one
// redraw per tick. (Measured on an i7-3770 with the popup open: an eased
// 180 ms step on the seconds hand cost ~4 % CPU, 70 ms ~2 %, a plain tick
// 0.2 %; a smooth sweep would redraw every frame.)
Item {
    id: root

    property bool showSeconds: true
    property int size: 180

    implicitWidth: size
    implicitHeight: size

    SystemClock {
        id: clock
        precision: root.showSeconds ? SystemClock.Seconds : SystemClock.Minutes
    }

    // The current time (for a digital readout next to the clock).
    readonly property date date: clock.date
    readonly property int h: clock.hours % 12
    readonly property int m: clock.minutes
    readonly property int s: clock.seconds

    // Face.
    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: Qt.alpha(Theme.fg, 0.04)
        border.width: 1
        border.color: Theme.border
    }

    // Minute marks; every fifth one (the hours) longer and brighter.
    Repeater {
        model: 60
        Item {
            required property int index
            readonly property bool hour: index % 5 === 0
            anchors.fill: parent
            rotation: index * 6
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                y: root.size * 0.05
                width: parent.hour ? 2.5 : 1.5
                height: parent.hour ? root.size * 0.07 : root.size * 0.03
                radius: width / 2
                color: parent.hour ? (parent.index % 15 === 0 ? Theme.fg : Theme.fgMuted) : Theme.fgDisabled
            }
        }
    }

    // A hand from the centre outward. `angle` in degrees, 0 = 12 o'clock.
    component Hand: Item {
        id: hand
        property real angle
        property real length
        property real thickness
        property color color
        // Short tail past the centre (seconds hand).
        property real tail: 0

        anchors.fill: parent
        rotation: angle

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            y: root.size / 2 - hand.length
            width: hand.thickness
            height: hand.length + hand.tail
            radius: width / 2
            color: hand.color
            antialiasing: true
        }
    }

    Hand {
        angle: root.h * 30 + root.m * 0.5
        length: root.size * 0.26
        thickness: 5
        color: Theme.fg
    }
    Hand {
        angle: root.m * 6
        length: root.size * 0.38
        thickness: 3.5
        color: Theme.fg
    }
    Hand {
        visible: root.showSeconds
        angle: root.s * 6
        length: root.size * 0.41
        tail: root.size * 0.09
        thickness: 1.5
        color: Theme.accent
    }

    // Centre cap.
    Rectangle {
        anchors.centerIn: parent
        width: 9
        height: 9
        radius: 4.5
        color: Theme.accent
        border.width: 2
        border.color: Theme.base
    }
}
