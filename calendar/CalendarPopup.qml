// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.components
import qs.core
import qs.services
import qs.theme

// Calendar popup under (or above) the clock. Open by clicking the clock, or
// `qs -c altair ipc call panels toggle calendar`. Closes on Esc, a click
// outside, or clicking the clock again (that click is outside the popup).
//
// Keys: Left/Right or PageUp/PageDown change the month, Home goes to today.
// Mouse: arrows, wheel (up = earlier), click the month title for today.
// Only exists while open (AltairPanel), and always opens on the current month.
//
// Under the calendar: the weather (Settings > Widgets place), as a strip with
// the next days or one compact line. The tune button (top right) opens a
// small menu to pick the clock, calendar and weather styles.
AltairPanel {
    id: root

    name: "calendar"
    // Under/over the bar, or beside a side bar, centred on the screen's height.
    dock: Theme.barVertical ? Theme.barPosition : Theme.barAtTop ? "top" : "bottom"
    centerVertically: Theme.barVertical
    fullWidth: false
    // Opens on the clock's side of the bar.
    along: ["left", "leftFirst"].indexOf(Config.bar.clockPosition) !== -1 ? "start"
        : ["right", "rightLast"].indexOf(Config.bar.clockPosition) !== -1 ? "end" : "center"
    slideDistance: 12
    readonly property string weatherStyle: !Weather.configured ? "off"
        : ["strip", "compact"].indexOf(Config.bar.popupWeather) !== -1 ? Config.bar.popupWeather : "off"
    readonly property int weatherHeight: weatherStyle === "strip" ? 116 : weatherStyle === "compact" ? 78 : 0
    // Small choice chips for the style menu.
    component Chips: Flow {
        id: chips
        property var options: []
        property string current
        signal picked(string value)
        Layout.fillWidth: true
        spacing: 4
        Repeater {
            model: chips.options
            MouseArea {
                id: chip
                required property var modelData
                readonly property bool on: chips.current === modelData.value
                implicitWidth: chipText.implicitWidth + 16
                implicitHeight: 26
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: chips.picked(modelData.value)
                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: chip.on ? Theme.accent : chip.containsMouse ? Theme.hover : Theme.surfaceRaised
                    Behavior on color { ColorAnimation { duration: Theme.anim.fast } }
                }
                StyledText {
                    id: chipText
                    anchors.centerIn: parent
                    text: chip.modelData.label
                    color: chip.on ? Theme.onAccent : Theme.fg
                    font.pixelSize: Theme.font.small
                }
            }
        }
    }

    panelWidth: 272 + (Config.bar.weekNumbers ? 26 : 0) + (Config.bar.analogClock ? 262 : 0)
    // Narrow (clock off): the style menu wraps onto more lines, give it room.
    panelHeight: 322 + weatherHeight + (Config.bar.analogClock || weatherHeight > 0 ? 0 : 48)

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

            // Weather is fetched while the popup shows it (cached for 30 min).
            Component.onCompleted: if (root.weatherStyle !== "off") Weather.users++
            Component.onDestruction: if (counted) Weather.users--
            readonly property bool counted: root.weatherStyle !== "off"

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Theme.space.l
                spacing: Theme.space.m

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Theme.space.l

            // ---- Round clock (optional) -------------------------------------------
            ColumnLayout {
                visible: Config.bar.analogClock
                Layout.alignment: Qt.AlignVCenter
                Layout.leftMargin: Theme.space.xs
                spacing: Theme.space.s

                AnalogClock {
                    id: analog
                    visible: Config.bar.clockStyle !== "digital"
                    Layout.alignment: Qt.AlignHCenter
                    size: 220
                    style: Config.bar.clockStyle
                    showSeconds: Config.bar.clockSeconds
                }
                // Digital: big time, seconds small beside it.
                Item {
                    visible: Config.bar.clockStyle === "digital"
                    Layout.alignment: Qt.AlignHCenter
                    implicitWidth: 220
                    implicitHeight: 220
                    SystemClock {
                        id: digital
                        precision: Config.bar.clockSeconds && Config.bar.clockStyle === "digital" ? SystemClock.Seconds : SystemClock.Minutes
                    }
                    Row {
                        anchors.centerIn: parent
                        spacing: 4
                        StyledText {
                            text: Qt.locale().toString(digital.date, "HH:mm")
                            font.pixelSize: 56
                            font.weight: Font.Light
                            tabular: true
                        }
                        StyledText {
                            visible: Config.bar.clockSeconds
                            anchors.baseline: parent.children[0].baseline
                            text: Qt.locale().toString(digital.date, "ss")
                            color: Theme.accent
                            font.pixelSize: 20
                            tabular: true
                        }
                    }
                }
                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: Config.bar.clockStyle === "digital"
                        ? cal.capitalise(Qt.locale().toString(clock.date, "dddd"))
                        : Qt.locale().toString(analog.date, Qt.locale().timeFormat(Locale.ShortFormat))
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
                        style: Config.bar.calendarStyle
                        cellSize: 32
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

            // ---- Weather ----------------------------------------------------------
            Rectangle {
                visible: root.weatherStyle !== "off"
                Layout.fillWidth: true
                implicitHeight: 1
                color: Theme.border
            }
            RowLayout {
                visible: root.weatherStyle !== "off"
                Layout.fillWidth: true
                Layout.preferredHeight: root.weatherHeight - Theme.space.m - 1
                spacing: Theme.space.l

                // Now.
                RowLayout {
                    spacing: Theme.space.s
                    Layout.fillWidth: root.weatherStyle === "compact"
                    Layout.minimumWidth: 0
                    Icon {
                        name: Weather.icon(Weather.code, Weather.isDay)
                        size: root.weatherStyle === "strip" ? 38 : 26
                        color: Theme.accent
                        fill: 1
                    }
                    ColumnLayout {
                        spacing: 0
                        StyledText {
                            text: Weather.loaded ? Weather.deg(Weather.temp) : "…"
                            font.pixelSize: root.weatherStyle === "strip" ? 26 : 18
                            font.weight: Font.DemiBold
                            tabular: true
                        }
                        StyledText {
                            text: Weather.loaded ? Weather.text(Weather.code) + (Weather.place ? " · " + Weather.place : "") : Weather.place
                            color: Theme.fgMuted
                            font.pixelSize: Theme.font.small
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                            Layout.maximumWidth: 200
                        }
                    }
                }
                Item { visible: root.weatherStyle === "strip"; Layout.fillWidth: true }
                // Next days (strip only).
                Repeater {
                    model: root.weatherStyle === "strip" ? Weather.daily.slice(1, 6) : []
                    ColumnLayout {
                        required property var modelData
                        spacing: 2
                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: cal.capitalise(Qt.locale().toString(new Date(modelData.date + "T12:00:00"), "ddd"))
                            color: Theme.fgMuted
                            font.pixelSize: Theme.font.small
                        }
                        Icon {
                            Layout.alignment: Qt.AlignHCenter
                            name: Weather.icon(modelData.code, true)
                            size: 20
                        }
                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: Weather.deg(modelData.max) + " " + Weather.deg(modelData.min)
                            font.pixelSize: Theme.font.small
                            tabular: true
                        }
                    }
                }
                // Compact: today's high/low.
                StyledText {
                    visible: root.weatherStyle === "compact" && Weather.daily.length > 0
                    text: Weather.daily.length > 0 ? "↑ " + Weather.deg(Weather.daily[0].max) + "   ↓ " + Weather.deg(Weather.daily[0].min) : ""
                    color: Theme.fgMuted
                    font.pixelSize: Theme.font.small
                    tabular: true
                }
            }
            }

            // ---- Style menu (tune button, top right) ---------------------------------
            IconButton {
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: Theme.space.s
                icon: "tune"
                size: 26
                iconSize: 16
                color: styles.open ? Theme.accent : Theme.fgDisabled
                z: 5
                onClicked: styles.open = !styles.open
            }
            // Click elsewhere: close the menu.
            MouseArea {
                anchors.fill: parent
                visible: styles.open
                z: 4
                onPressed: styles.open = false
            }
            Item {
                id: styles
                property bool open: false
                z: 6
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.topMargin: Theme.space.s + 30
                anchors.rightMargin: Theme.space.s
                // Fits the popup, also when it narrows (clock off): the
                // choices wrap onto more lines.
                width: Math.min(300, parent.width - Theme.space.s * 2)
                height: stylesCol.implicitHeight + Theme.space.m * 2
                opacity: open ? 1 : 0
                visible: opacity > 0
                scale: open ? 1 : 0.95
                transformOrigin: Item.TopRight
                Behavior on opacity { NumberAnimation { duration: Theme.anim.fast; easing.type: Easing.OutCubic } }
                Behavior on scale { NumberAnimation { duration: Theme.anim.normal; easing.type: Easing.OutQuint } }

                GlassBackground {
                    anchors.fill: parent
                    radius: Theme.radius.m
                    solidity: 0.75
                }
                ColumnLayout {
                    id: stylesCol
                    anchors.fill: parent
                    anchors.margins: Theme.space.m
                    spacing: Theme.space.s

                    StyledText { text: "Clock"; color: Theme.fgMuted; font.pixelSize: Theme.font.small; font.weight: Font.DemiBold }
                    Chips {
                        options: [{ label: "Classic", value: "classic" }, { label: "Minimal", value: "minimal" },
                                  { label: "Numbers", value: "numbers" }, { label: "Dots", value: "dots" },
                                  { label: "Digital", value: "digital" }, { label: "Off", value: "off" }]
                        current: Config.bar.analogClock ? Config.bar.clockStyle : "off"
                        onPicked: value => {
                            if (value === "off") {
                                Config.bar.analogClock = false;
                            } else {
                                Config.bar.analogClock = true;
                                Config.bar.clockStyle = value;
                            }
                        }
                    }
                    StyledText { text: "Position in the bar"; color: Theme.fgMuted; font.pixelSize: Theme.font.small; font.weight: Font.DemiBold }
                    Chips {
                        options: Theme.barVertical
                            ? [{ label: "Top first", value: "leftFirst" }, { label: "Top", value: "left" }, { label: "Middle", value: "center" },
                               { label: "Bottom", value: "right" }, { label: "Bottom last", value: "rightLast" }]
                            : [{ label: "Left first", value: "leftFirst" }, { label: "Left", value: "left" }, { label: "Middle", value: "center" },
                               { label: "Right", value: "right" }, { label: "Right last", value: "rightLast" }]
                        current: Config.bar.clockPosition
                        onPicked: value => Config.bar.clockPosition = value
                    }
                    StyledText { text: "Calendar"; color: Theme.fgMuted; font.pixelSize: Theme.font.small; font.weight: Font.DemiBold }
                    Chips {
                        options: [{ label: "Classic", value: "classic" }, { label: "Clean", value: "clean" }, { label: "Bold", value: "bold" }]
                        current: Config.bar.calendarStyle
                        onPicked: value => Config.bar.calendarStyle = value
                    }
                    StyledText { text: "Weather"; color: Theme.fgMuted; font.pixelSize: Theme.font.small; font.weight: Font.DemiBold }
                    Chips {
                        options: [{ label: "Strip", value: "strip" }, { label: "Compact", value: "compact" }, { label: "Off", value: "off" }]
                        current: Config.bar.popupWeather
                        onPicked: value => Config.bar.popupWeather = value
                    }
                    StyledText {
                        visible: !Weather.configured
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                        text: "Choose your city in Settings > Widgets to see the weather here."
                        color: Theme.fgDisabled
                        font.pixelSize: Theme.font.small
                    }
                }
            }
        }
    }
}
