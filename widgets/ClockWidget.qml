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
//   stacked  hours over minutes, large (minutes in the accent colour)
//   split    hours | minutes either side of a thin line, date below
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

    readonly property bool classicLike: ["classic", "light", "minimal", "date"].indexOf(style) !== -1
    readonly property string hh: Qt.locale().toString(clock.date, "HH")
    readonly property string mm: Qt.locale().toString(clock.date, "mm")

    // ---- Stacked ----------------------------------------------------------------
    ColumnLayout {
        anchors.centerIn: parent
        visible: root.style === "stacked"
        spacing: -26
        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: root.hh
            font.pixelSize: 96
            font.weight: Font.Bold
            font.letterSpacing: -3
            tabular: true
        }
        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: root.mm
            color: Theme.accent
            font.pixelSize: 96
            font.weight: Font.Bold
            font.letterSpacing: -3
            tabular: true
        }
    }

    // ---- Split ------------------------------------------------------------------
    ColumnLayout {
        anchors.centerIn: parent
        visible: root.style === "split"
        spacing: 6
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 18
            StyledText {
                text: root.hh
                font.pixelSize: 64
                font.weight: Font.Light
                tabular: true
            }
            Rectangle {
                implicitWidth: 2
                implicitHeight: 52
                radius: 1
                color: Theme.accent
            }
            StyledText {
                text: root.mm
                font.pixelSize: 64
                font.weight: Font.Light
                tabular: true
            }
        }
        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: root.cap(Qt.locale().toString(clock.date, "ddd d MMMM"))
            color: Theme.fgMuted
            font.pixelSize: 14
            font.letterSpacing: 1
        }
    }

    ColumnLayout {
        anchors.centerIn: parent
        visible: root.classicLike
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
