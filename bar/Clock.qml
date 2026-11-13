// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.components
import qs.theme

// Date and time in the user's locale. Updates once a minute (SystemClock with
// minute precision), so it costs nothing in between.
RowLayout {
    spacing: Theme.space.s

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    StyledText {
        text: Qt.locale().toString(clock.date, "ddd d MMM")
        color: Theme.fgMuted
    }
    StyledText {
        text: Qt.locale().toString(clock.date, Qt.locale().timeFormat(Locale.ShortFormat))
        font.weight: Font.DemiBold
        tabular: true
    }
}
