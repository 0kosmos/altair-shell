// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Layouts
import qs.components
import qs.theme

// One month as a 6 x 7 grid of days (always 6 rows, so the size never
// changes between months), with weekday names on top and optional ISO week
// numbers on the left. Display only; reusable (e.g. the dashboard).
//
// Weekday names and the first day of the week follow the locale.
ColumnLayout {
    id: root

    property int year: new Date().getFullYear()
    property int month: new Date().getMonth()        // 0–11
    property date today: new Date()
    property bool weekNumbers: false
    property int cellSize: 36
    // "classic": today filled; "clean": other months' days hidden, today a
    // ring; "bold": rounded squares, today filled, weekends in the accent.
    property string style: "classic"
    readonly property var locale: Qt.locale()

    spacing: Theme.space.xs

    // The 42 dates shown, starting on the locale's first weekday on or before
    // the 1st of the month. (Locale.Sunday = 0 … Saturday = 6, like getDay().)
    readonly property var days: {
        const first = new Date(year, month, 1);
        const offset = (first.getDay() - locale.firstDayOfWeek + 7) % 7;
        const list = [];
        for (let i = 0; i < 42; i++)
            list.push(new Date(year, month, 1 - offset + i));
        return list;
    }

    function sameDay(a: date, b: date): bool {
        return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
    }

    // ISO 8601 week number: the week with the year's first Thursday is week 1.
    function isoWeek(d: date): int {
        const t = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()));
        const day = t.getUTCDay() || 7;
        t.setUTCDate(t.getUTCDate() + 4 - day);
        const yearStart = new Date(Date.UTC(t.getUTCFullYear(), 0, 1));
        return Math.ceil(((t - yearStart) / 86400000 + 1) / 7);
    }

    // ---- Weekday names -------------------------------------------------------
    RowLayout {
        spacing: 0

        Item {
            visible: root.weekNumbers
            implicitWidth: root.cellSize * 0.8
        }
        Repeater {
            model: 7
            StyledText {
                required property int index
                Layout.preferredWidth: root.cellSize
                Layout.preferredHeight: 20
                horizontalAlignment: Text.AlignHCenter
                text: root.locale.dayName((root.locale.firstDayOfWeek + index) % 7, Locale.ShortFormat)
                color: Theme.fgDisabled
                font.pixelSize: Theme.font.small
                font.weight: Font.DemiBold
                font.capitalization: Font.Capitalize
            }
        }
    }

    // ---- Weeks -----------------------------------------------------------------
    Repeater {
        model: 6

        RowLayout {
            id: week
            required property int index
            spacing: 0

            StyledText {
                visible: root.weekNumbers
                Layout.preferredWidth: root.cellSize * 0.8
                Layout.preferredHeight: root.cellSize
                horizontalAlignment: Text.AlignHCenter
                text: root.isoWeek(root.days[week.index * 7 + 3])   // Thursday-ish of the row
                color: Theme.fgDisabled
                font.pixelSize: Theme.font.small - 1
                tabular: true
            }

            Repeater {
                model: 7

                Item {
                    id: cell
                    required property int index
                    readonly property date day: root.days[week.index * 7 + index]
                    readonly property bool inMonth: day.getMonth() === root.month
                    readonly property bool isToday: root.sameDay(day, root.today)
                    readonly property bool weekend: day.getDay() === 0 || day.getDay() === 6

                    implicitWidth: root.cellSize
                    implicitHeight: root.cellSize

                    Rectangle {
                        anchors.centerIn: parent
                        width: root.cellSize - 4
                        height: width
                        radius: root.style === "bold" ? Theme.radius.s : width / 2
                        // No colour animation: while the month slides it would
                        // leave a fading "today" circle on the wrong day.
                        color: cell.isToday && root.style !== "clean" ? Theme.accent
                            : root.style === "bold" && cell.inMonth ? Theme.surfaceRaised : "transparent"
                        border.width: cell.isToday && root.style === "clean" ? 2 : 0
                        border.color: Theme.accent
                    }

                    StyledText {
                        anchors.centerIn: parent
                        visible: cell.inMonth || root.style !== "clean"
                        text: cell.day.getDate()
                        color: cell.isToday && root.style !== "clean" ? Theme.onAccent
                            : cell.isToday ? Theme.accent
                            : !cell.inMonth ? Theme.fgDisabled
                            : root.style === "bold" && cell.weekend ? Theme.accent : Theme.fg
                        font.pixelSize: Theme.font.body - 1
                        font.weight: cell.isToday ? Font.DemiBold : Font.Normal
                        tabular: true
                    }
                }
            }
        }
    }
}
