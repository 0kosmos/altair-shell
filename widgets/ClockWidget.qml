// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.components
import qs.theme

// Big time and the date, in the user's locale. Base size 320 x 150 (scaled
// by WidgetFrame). Updates once a minute.
Item {
    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 0

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: Qt.locale().toString(clock.date, Qt.locale().timeFormat(Locale.ShortFormat))
            font.pixelSize: 64
            font.weight: Font.DemiBold
            font.letterSpacing: -1
            tabular: true
        }
        StyledText {
            Layout.alignment: Qt.AlignHCenter
            // Only the first letter capitalised ("Sabato 14 novembre").
            text: {
                const s = Qt.locale().toString(clock.date, "dddd d MMMM");
                return s.charAt(0).toUpperCase() + s.slice(1);
            }
            color: Theme.fgMuted
            font.pixelSize: 18
        }
    }
}
