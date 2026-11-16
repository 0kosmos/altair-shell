// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Layouts
import Quickshell.Wayland
import Quickshell
import qs.components
import qs.core
import qs.services
import qs.theme

// Weather (services/Weather.qml, Open-Meteo). Styles (sizes in
// services/Widgets.qml):
//   card      big icon, temperature, condition, place, high/low
//   forecast  now + the next 5 days
//   hourly    the next 6 hours
//   minimal   icon and temperature on one line (fits under a clock)
// Without a place chosen it points to Settings > Widgets.
Item {
    id: root
    property string style: "card"
    // False while windows cover the desktop (WidgetFrame): effects pause.
    property bool live: true

    Component.onCompleted: Weather.users++
    Component.onDestruction: Weather.users--

    readonly property var today: Weather.daily[0] ?? null
    function dayName(iso: string): string {
        const d = new Date(iso + "T12:00:00");
        const s = Qt.locale().toString(d, "ddd");
        return s.charAt(0).toUpperCase() + s.slice(1);
    }

    // Set by WidgetFrame: the widget's rect on its monitor, its corner radius,
    // the monitor, and whether it is being dragged.
    property rect frameRect
    property real frameRadius: Theme.radius.l
    property string screenName: ""
    property bool moving: false

    // Sun glow, stars, haze: static, drawn right here behind the text.
    readonly property bool effects: Config.widgets.weatherEffects && Weather.configured && Weather.loaded
    Loader {
        anchors.fill: parent
        active: root.effects
        sourceComponent: WeatherEffect {
            code: Weather.code
            day: Weather.isDay
            drawMoving: false
        }
    }

    // Rain, snow, storms move: drawn in a small window of their own over the
    // widget (drops run over the glass), see FrameOverlay. Only while
    // visible and not covered.
    FrameOverlay {
        wanted: root.effects && fx.moving && root.live && Theme.animations
        frameRect: root.frameRect
        screenName: root.screenName
        moving: root.moving
        content: Component {
            WeatherEffect {
                code: Weather.code
                day: Weather.isDay
                radius: root.frameRadius
                drawStatic: false
            }
        }
    }
    // Only for its `moving` flag (what the code means).
    WeatherEffect {
        id: fx
        visible: false
        code: Weather.code
        drawStatic: false
        drawMoving: false
    }

    // ---- Not set up / not loaded --------------------------------------------------------
    ColumnLayout {
        anchors.centerIn: parent
        visible: !Weather.configured || !Weather.loaded
        spacing: 4
        Icon {
            Layout.alignment: Qt.AlignHCenter
            name: Weather.failed ? "cloud_off" : "partly_cloudy_day"
            size: 26
            color: Theme.fgMuted
        }
        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: !Weather.configured ? "Choose your city in Settings > Widgets"
                : Weather.failed ? "Weather unavailable" : "Loading…"
            color: Theme.fgMuted
            font.pixelSize: Theme.font.small
        }
    }

    Loader {
        anchors.fill: parent
        active: Weather.configured && Weather.loaded
        sourceComponent: root.style === "forecast" ? forecast : root.style === "hourly" ? hourly
            : root.style === "minimal" ? minimal : card
    }

    component Temp: StyledText {
        property real value
        text: Weather.deg(value)
        tabular: true
    }

    Component {
        id: card
        RowLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 14
            Icon {
                name: Weather.icon(Weather.code, Weather.isDay)
                size: 64
                fill: 0
                color: Theme.accent
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Temp {
                    value: Weather.temp
                    font.pixelSize: 44
                    font.weight: Font.DemiBold
                }
                StyledText {
                    Layout.fillWidth: true
                    text: Weather.text(Weather.code) + " · feels " + Weather.deg(Weather.feels)
                    color: Theme.fgMuted
                    font.pixelSize: Theme.font.small
                }
                StyledText {
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    text: Weather.city + (root.today ? "   ↑ " + Weather.deg(root.today.max) + "  ↓ " + Weather.deg(root.today.min) : "")
                    font.pixelSize: Theme.font.small
                }
            }
        }
    }

    Component {
        id: forecast
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 8
            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                Icon {
                    name: Weather.icon(Weather.code, Weather.isDay)
                    size: 34
                    fill: 0
                    color: Theme.accent
                }
                Temp {
                    value: Weather.temp
                    font.pixelSize: 28
                    font.weight: Font.DemiBold
                }
                StyledText {
                    Layout.fillWidth: true
                    text: Weather.text(Weather.code) + "\n" + Weather.city
                    color: Theme.fgMuted
                    font.pixelSize: Theme.font.small
                    lineHeight: 1.1
                }
            }
            // Equal columns, sized explicitly (a RowLayout kept them at their
            // content width).
            Row {
                id: days
                Layout.fillWidth: true
                Layout.fillHeight: true
                readonly property var list: Weather.daily.slice(1, 6)
                Repeater {
                    model: days.list
                    Item {
                        required property var modelData
                        width: days.width / Math.max(1, days.list.length)
                        height: days.height
                        Column {
                            anchors.centerIn: parent
                            spacing: 2
                            StyledText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: root.dayName(modelData.date)
                                color: Theme.fgMuted
                                font.pixelSize: 11
                            }
                            Icon {
                                anchors.horizontalCenter: parent.horizontalCenter
                                name: Weather.icon(modelData.code, true)
                                size: 22
                            }
                            StyledText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: Weather.deg(modelData.max) + " " + Weather.deg(modelData.min)
                                font.pixelSize: 11
                                tabular: true
                            }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: hourly
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 6
            StyledText {
                text: Weather.city + "  ·  " + Weather.deg(Weather.temp) + " " + Weather.text(Weather.code)
                color: Theme.fgMuted
                font.pixelSize: Theme.font.small
            }
            Row {
                id: hours
                Layout.fillWidth: true
                Layout.fillHeight: true
                Repeater {
                    model: Weather.hourly
                    Item {
                        required property var modelData
                        width: hours.width / Math.max(1, Weather.hourly.length)
                        height: hours.height
                        Column {
                            anchors.centerIn: parent
                            spacing: 3
                            StyledText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: Qt.locale().toString(modelData.time, Qt.locale().timeFormat(Locale.ShortFormat))
                                color: Theme.fgMuted
                                font.pixelSize: 11
                                tabular: true
                            }
                            Icon {
                                anchors.horizontalCenter: parent.horizontalCenter
                                name: Weather.icon(modelData.code, modelData.isDay)
                                size: 24
                            }
                            Temp {
                                anchors.horizontalCenter: parent.horizontalCenter
                                value: modelData.temp
                                font.pixelSize: Theme.font.small
                                font.weight: Font.DemiBold
                            }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: minimal
        RowLayout {
            anchors.centerIn: parent
            spacing: 8
            Icon {
                name: Weather.icon(Weather.code, Weather.isDay)
                size: 26
                fill: 0
                color: Theme.accent
            }
            Temp {
                value: Weather.temp
                font.pixelSize: 24
                font.weight: Font.DemiBold
            }
            StyledText {
                text: Weather.text(Weather.code)
                color: Theme.fgMuted
                font.pixelSize: Theme.font.small
            }
        }
    }
}
