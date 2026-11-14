// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.components
import qs.theme

// Time and date in the user's locale. Base size 320 x 150 (scaled by
// WidgetFrame). Updates once a minute. Styles:
//   classic  time + date
//   light    large thin time, small spaced-out date
//   minimal  big time only
//   date     the weekday large, date and time below
Item {
    id: root
    property string style: "classic"

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    readonly property string time: Qt.locale().toString(clock.date, Qt.locale().timeFormat(Locale.ShortFormat))
    function cap(s: string): string {
        return s.charAt(0).toUpperCase() + s.slice(1);
    }

    ColumnLayout {
        anchors.centerIn: parent
        spacing: root.style === "light" ? 4 : 0

        // Main line.
        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: root.style === "date" ? root.cap(Qt.locale().toString(clock.date, "dddd")) : root.time
            font.pixelSize: root.style === "minimal" ? 84 : root.style === "light" ? 76 : root.style === "date" ? 46 : 64
            font.weight: root.style === "light" ? Font.Light : root.style === "date" ? Font.Medium : Font.DemiBold
            font.letterSpacing: root.style === "date" ? 0 : -1
            tabular: root.style !== "date"
        }
        // Second line.
        StyledText {
            Layout.alignment: Qt.AlignHCenter
            visible: root.style !== "minimal"
            text: root.style === "date" ? Qt.locale().toString(clock.date, "d MMMM") + "  ·  " + root.time
                : root.style === "light" ? Qt.locale().toString(clock.date, "dddd d MMMM").toUpperCase()
                : root.cap(Qt.locale().toString(clock.date, "dddd d MMMM"))
            color: Theme.fgMuted
            font.pixelSize: root.style === "light" ? 13 : 18
            font.letterSpacing: root.style === "light" ? 2.5 : 0
        }
    }
}
