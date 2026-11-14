// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import Quickshell
import qs.components
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
    // "classic" (face, all minute marks), "minimal" (no face, 12 marks),
    // "numbers" (hour numerals, faint minute marks), "dots" (dots for hours).
    property string style: "classic"

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

    // Face (not in "minimal").
    Rectangle {
        anchors.fill: parent
        visible: root.style !== "minimal"
        radius: width / 2
        color: Qt.alpha(Theme.fg, 0.04)
        border.width: 1
        border.color: Theme.border
    }

    // Marks. classic: 60, the hours longer and brighter; minimal: 12 bold
    // hour marks; numbers: faint minute marks (numerals below); dots: 12 dots.
    Repeater {
        model: root.style === "minimal" || root.style === "dots" ? 12 : 60
        Item {
            required property int index
            readonly property int minute: root.style === "minimal" || root.style === "dots" ? index * 5 : index
            readonly property bool hour: minute % 5 === 0
            readonly property bool quarter: minute % 15 === 0
            anchors.fill: parent
            rotation: minute * 6
            // Numbers style: no marks where the numerals are.
            visible: !(root.style === "numbers" && hour)
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                readonly property bool dot: root.style === "dots"
                y: root.size * (dot ? 0.07 : 0.05)
                width: dot ? (parent.quarter ? 7 : 4.5) : root.style === "minimal" ? (parent.quarter ? 4 : 3) : parent.hour ? 2.5 : 1.5
                height: dot ? width : root.style === "minimal" ? root.size * (parent.quarter ? 0.1 : 0.07)
                    : parent.hour ? root.size * 0.07 : root.size * 0.03
                radius: width / 2
                color: dot || root.style === "minimal" ? (parent.quarter ? Theme.fg : Theme.fgMuted)
                    : parent.hour ? (parent.quarter ? Theme.fg : Theme.fgMuted) : Theme.fgDisabled
            }
        }
    }

    // Numbers style: 1–12.
    Repeater {
        model: root.style === "numbers" ? 12 : 0
        StyledText {
            required property int index
            readonly property real a: (index + 1) * Math.PI / 6
            readonly property real r: root.size * 0.37
            x: root.size / 2 + Math.sin(a) * r - width / 2
            y: root.size / 2 - Math.cos(a) * r - height / 2
            text: index + 1
            font.pixelSize: Math.round(root.size * 0.085)
            font.weight: (index + 1) % 3 === 0 ? Font.DemiBold : Font.Normal
            color: (index + 1) % 3 === 0 ? Theme.fg : Theme.fgMuted
            tabular: true
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
