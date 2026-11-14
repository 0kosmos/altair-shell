// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import qs.calendar

// The calendar's round clock as a desktop widget. Base size 220 x 220.
// No seconds hand: on the desktop it is always visible, and a tick every
// second redraws the blurred widget layer (~0.75 % CPU on an i7-3770 vs 0.0 %
// with minute updates). The calendar popup keeps its seconds hand.
Item {
    AnalogClock {
        anchors.centerIn: parent
        size: 196
        showSeconds: false
    }
}
