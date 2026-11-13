// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import Quickshell
import qs.components
import qs.core
import qs.theme

// Date and time in the user's locale. Updates once a minute (SystemClock with
// minute precision), so it costs nothing in between. Click: the calendar
// popup (calendar/CalendarPopup.qml), unless turned off in Settings > Bar.
BarButton {
    interactive: Config.bar.clockPopup
    spacing: Theme.space.s
    onClicked: ShellState.toggle("calendar")

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    StyledText {
        visible: Config.bar.showDate
        text: Qt.locale().toString(clock.date, "ddd d MMM")
        color: ShellState.openPanel === "calendar" ? Theme.fg : Theme.fgMuted
    }
    StyledText {
        text: Qt.locale().toString(clock.date, Qt.locale().timeFormat(Locale.ShortFormat))
        font.weight: Font.DemiBold
        tabular: true
    }
}
