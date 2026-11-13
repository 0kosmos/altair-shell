// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.components
import qs.core
import qs.theme

// Calendar popup under (or above) the clock. Open by clicking the clock, or
// `qs -c altair ipc call panels toggle calendar`. Closes on Esc, a click
// outside, or clicking the clock again (that click is outside the popup).
//
// Keys: Left/Right or PageUp/PageDown change the month, Home goes to today.
// Mouse: arrows, wheel (up = earlier), click the month title for today.
// Only exists while open (AltairPanel), and always opens on the current month.
AltairPanel {
    id: root

    name: "calendar"
    dock: Theme.barAtTop ? "top" : "bottom"
    fullWidth: false
    slideDistance: 12
    panelWidth: 286 + (Config.bar.weekNumbers ? 27 : 0) + (Config.bar.analogClock ? 222 : 0)
    panelHeight: 334

    content: Component {
        FocusScope {
            id: cal
            focus: true

            // Changes at midnight; hour precision is plenty for "today".
            SystemClock {
                id: clock
                precision: SystemClock.Hours
            }

            property int year: clock.date.getFullYear()
            property int month: clock.date.getMonth()
            readonly property bool onToday: year === clock.date.getFullYear() && month === clock.date.getMonth()

            // Move by `delta` months; the grid slides in from that side.
            function shift(delta: int): void {
                const d = new Date(year, month + delta, 1);
                year = d.getFullYear();
                month = d.getMonth();
                slide.from = delta > 0 ? 28 : -28;
                slideIn.restart();
            }
            function goToday(): void {
                const delta = (clock.date.getFullYear() - year) * 12 + clock.date.getMonth() - month;
                if (delta !== 0)
                    shift(delta);
            }

            function capitalise(s: string): string {
                return s.charAt(0).toUpperCase() + s.slice(1);
            }

            Keys.onLeftPressed: shift(-1)
            Keys.onRightPressed: shift(1)
            Keys.onPressed: event => {
                if (event.key === Qt.Key_PageUp)
                    shift(-1);
                else if (event.key === Qt.Key_PageDown)
                    shift(1);
                else if (event.key === Qt.Key_Home)
                    goToday();
                else
                    return;
                event.accepted = true;
            }

            // Wheel anywhere on the popup: one notch = one month.
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.NoButton
                property int accum: 0
                onWheel: wheel => {
                    accum += wheel.angleDelta.y;
                    while (Math.abs(accum) >= 120) {
                        const dir = accum > 0 ? -1 : 1;
                        accum += dir * 120;
                        cal.shift(dir);
                    }
                }
            }

            RowLayout {
                anchors.fill: parent
                anchors.margins: Theme.space.l
                spacing: Theme.space.l

            // ---- Round clock (optional) -------------------------------------------
            ColumnLayout {
                visible: Config.bar.analogClock
                Layout.alignment: Qt.AlignVCenter
                Layout.leftMargin: Theme.space.xs
                spacing: Theme.space.m

                AnalogClock {
                    id: analog
                    Layout.alignment: Qt.AlignHCenter
                    size: 180
                    showSeconds: Config.bar.clockSeconds
                }
                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: Qt.locale().toString(analog.date, Qt.locale().timeFormat(Locale.ShortFormat))
                    color: Theme.fgMuted
                    font.pixelSize: Theme.font.body
                    font.weight: Font.Medium
                    tabular: true
                }
            }

            Rectangle {
                visible: Config.bar.analogClock
                Layout.fillHeight: true
                Layout.topMargin: Theme.space.s
                Layout.bottomMargin: Theme.space.s
                implicitWidth: 1
                color: Theme.border
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Theme.space.s

                // Today, in full ("sabato 14 novembre").
                StyledText {
                    Layout.fillWidth: true
                    // Only the first letter: "Sabato 14 novembre", not "… Novembre".
                    text: cal.capitalise(Qt.locale().toString(clock.date, "dddd d MMMM"))
                    color: Theme.fgMuted
                    font.pixelSize: Theme.font.small
                }

                // ---- Month title + arrows --------------------------------------
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    // Click: back to the current month.
                    MouseArea {
                        id: title
                        Layout.fillWidth: true
                        implicitHeight: 32
                        hoverEnabled: true
                        cursorShape: cal.onToday ? Qt.ArrowCursor : Qt.PointingHandCursor
                        onClicked: cal.goToday()

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Qt.locale().standaloneMonthName(cal.month, Locale.LongFormat)
                                + (cal.year !== clock.date.getFullYear() ? " " + cal.year : "")
                            color: title.containsMouse && !cal.onToday ? Theme.accent : Theme.fg
                            font.pixelSize: Theme.font.title
                            font.weight: Font.DemiBold
                            font.capitalization: Font.Capitalize
                        }
                    }
                    IconButton {
                        icon: "chevron_left"
                        iconSize: 20
                        onClicked: cal.shift(-1)
                    }
                    IconButton {
                        icon: "chevron_right"
                        iconSize: 20
                        onClicked: cal.shift(1)
                    }
                }

                // ---- Grid (slides when the month changes) -----------------------
                Item {
                    Layout.fillWidth: true
                    implicitHeight: monthView.implicitHeight
                    clip: true

                    MonthView {
                        id: monthView
                        x: slide.offset
                        opacity: 1 - Math.abs(slide.offset) / 40
                        year: cal.year
                        month: cal.month
                        today: clock.date
                        weekNumbers: Config.bar.weekNumbers
                        cellSize: 34
                    }

                    QtObject {
                        id: slide
                        property real offset: 0
                        property real from: 0
                    }
                    NumberAnimation {
                        id: slideIn
                        target: slide
                        property: "offset"
                        from: slide.from
                        to: 0
                        duration: Theme.anim.normal
                        easing.type: Theme.anim.easingSlide
                    }
                }

                // Agenda / events would go here (a Loader under the grid, with
                // panelHeight grown to fit). Deliberately not built yet.

                Item { Layout.fillHeight: true }
            }
            }
        }
    }
}
