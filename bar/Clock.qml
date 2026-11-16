// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.components
import qs.core
import qs.theme

// Date and time in the user's locale. Updates once a minute (SystemClock with
// minute precision), so it costs nothing in between. Click: the calendar
// popup (calendar/CalendarPopup.qml), unless turned off in Settings > Bar.
BarButton {
    id: btn
    interactive: Config.bar.clockPopup
    spacing: Theme.space.s
    onClicked: ShellState.toggle("calendar")

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    StyledText {
        visible: Config.bar.showDate && !Theme.barVertical
        text: Qt.locale().toString(clock.date, "ddd d MMM")
        color: ShellState.openPanel === "calendar" ? Theme.fg : Theme.fgMuted
    }
    StyledText {
        visible: !Theme.barVertical
        text: Qt.locale().toString(clock.date, Qt.locale().timeFormat(Locale.ShortFormat))
        font.weight: Font.DemiBold
        tabular: true
    }

    // Side bar: hours over minutes (24 h or 12 h like the locale), and the
    // day of the month under them when the date is on.
    readonly property bool h12: Qt.locale().timeFormat(Locale.ShortFormat).indexOf("AP") !== -1
        || Qt.locale().timeFormat(Locale.ShortFormat).indexOf("ap") !== -1
    StyledText {
        visible: Theme.barVertical
        Layout.alignment: Qt.AlignHCenter
        text: Qt.locale().toString(clock.date, btn.h12 ? "h" : "HH")
        font.weight: Font.DemiBold
        tabular: true
    }
    StyledText {
        visible: Theme.barVertical
        Layout.alignment: Qt.AlignHCenter
        Layout.topMargin: -4
        text: Qt.locale().toString(clock.date, "mm")
        font.weight: Font.DemiBold
        tabular: true
    }
    Rectangle {
        visible: Theme.barVertical && Config.bar.showDate
        Layout.alignment: Qt.AlignHCenter
        implicitWidth: 14
        implicitHeight: 1
        color: Theme.border
    }
    StyledText {
        visible: Theme.barVertical && Config.bar.showDate
        Layout.alignment: Qt.AlignHCenter
        text: Qt.locale().toString(clock.date, "d")
        color: Theme.fgMuted
        font.pixelSize: Theme.font.small
        tabular: true
    }
}
