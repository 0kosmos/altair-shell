// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import qs.components
import qs.services
import qs.theme

// Music equalizer (services/Equalizer.qml): on/off, preset, 6 bands you can
// drag (−12 … +12 dB). Moving a band turns the curve into "Custom". Only the
// music player's audio goes through it. Base size 380 x 230.
Item {
    id: root
    property string style: ""

    readonly property bool on: Equalizer.enabled

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 8

        // ---- Header: title, preset, on/off ----------------------------------------
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.space.s

            Icon {
                name: "tune"
                size: 18
                color: root.on ? Theme.accent : Theme.fgMuted
            }
            StyledText {
                text: "Equalizer"
                font.weight: Font.DemiBold
            }
            Item { Layout.fillWidth: true }

            // Preset: arrows, or click the name for the next one.
            IconButton {
                icon: "chevron_left"
                size: 24
                iconSize: 18
                onClicked: Equalizer.stepPreset(-1)
            }
            MouseArea {
                implicitWidth: 112
                implicitHeight: 24
                cursorShape: Qt.PointingHandCursor
                onClicked: Equalizer.stepPreset(1)
                onWheel: wheel => Equalizer.stepPreset(wheel.angleDelta.y > 0 ? -1 : 1)
                StyledText {
                    anchors.centerIn: parent
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: Equalizer.presetName
                    font.pixelSize: Theme.font.small
                    font.weight: Font.Medium
                }
            }
            IconButton {
                icon: "chevron_right"
                size: 24
                iconSize: 18
                onClicked: Equalizer.stepPreset(1)
            }
            Toggle {
                Layout.leftMargin: Theme.space.xs
                checked: root.on
                onToggled: value => Equalizer.setEnabled(value)
            }
        }

        // ---- Bands ----------------------------------------------------------------
        Item {
            id: bands
            Layout.fillWidth: true
            Layout.fillHeight: true
            opacity: root.on ? 1 : 0.5
            Behavior on opacity {
                NumberAnimation { duration: Theme.anim.fast }
            }

            readonly property int n: Equalizer.freqs.length
            readonly property real colW: width / n
            // Slider track area (between the value on top and the label below).
            readonly property real trackTop: 18
            readonly property real trackBottom: height - 18
            function yOf(db: real): real {
                return trackTop + (1 - (db + Equalizer.maxGain) / (Equalizer.maxGain * 2)) * (trackBottom - trackTop);
            }

            // 0 dB line.
            Rectangle {
                x: 0
                width: parent.width
                y: bands.yOf(0)
                height: 1
                color: Theme.border
            }

            // The curve through the knobs.
            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeWidth: 2
                    strokeColor: Qt.alpha(Theme.accent, 0.7)
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    joinStyle: ShapePath.RoundJoin
                    // Through the animated knob positions, so it glides with them.
                    PathPolyline {
                        path: {
                            const l = [];
                            for (let i = 0; i < cols.count; i++) {
                                const c = cols.itemAt(i);
                                l.push(Qt.point((i + 0.5) * bands.colW, bands.yOf(c ? c.shown : 0)));
                            }
                            return l;
                        }
                    }
                }
            }

            Repeater {
                id: cols
                model: bands.n

                Item {
                    id: col
                    required property int index
                    readonly property real db: Equalizer.gains[index] ?? 0
                    // Shown value: glides to presets and scroll steps, follows
                    // the pointer exactly while dragging.
                    property real shown: db
                    Behavior on shown {
                        enabled: !drag.pressed
                        NumberAnimation { duration: Theme.anim.slow; easing.type: Theme.anim.easingSlide }
                    }
                    x: index * bands.colW
                    width: bands.colW
                    height: bands.height

                    StyledText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 0
                        text: (col.db > 0 ? "+" : "") + col.db.toFixed(col.db % 1 === 0 ? 0 : 1)
                        color: drag.pressed ? Theme.fg : Theme.fgMuted
                        font.pixelSize: 10
                        tabular: true
                    }
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: bands.trackTop
                        height: bands.trackBottom - bands.trackTop
                        width: 4
                        radius: 2
                        color: Theme.pressed
                    }
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: drag.containsMouse || drag.pressed ? 16 : 13
                        height: width
                        radius: width / 2
                        y: bands.yOf(col.shown) - height / 2
                        color: Theme.fg
                        border.width: 2
                        border.color: Theme.accent
                        Behavior on width {
                            NumberAnimation { duration: Theme.anim.fast }
                        }
                    }
                    StyledText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        text: Equalizer.freqLabels[col.index]
                        color: Theme.fgMuted
                        font.pixelSize: 10
                    }

                    MouseArea {
                        id: drag
                        anchors.fill: parent
                        hoverEnabled: true
                        preventStealing: true
                        cursorShape: Qt.SizeVerCursor
                        function ratio(y: real): real {
                            return 1 - (y - bands.trackTop) / (bands.trackBottom - bands.trackTop);
                        }
                        function set(y: real): void {
                            Equalizer.setBand(col.index, ratio(y) * Equalizer.maxGain * 2 - Equalizer.maxGain);
                        }
                        onPressed: mouse => {
                            set(mouse.y);
                            Sounds.slideBegin(ratio(mouse.y), Equalizer.maxGain * 2);
                        }
                        onPositionChanged: mouse => {
                            if (pressed) {
                                set(mouse.y);
                                Sounds.slideTo(ratio(mouse.y), Equalizer.maxGain * 2);
                            }
                        }
                        onWheel: wheel => Equalizer.setBand(col.index, col.db + (wheel.angleDelta.y > 0 ? 0.5 : -0.5))
                        onDoubleClicked: Equalizer.setBand(col.index, 0)
                    }
                }
            }
        }
    }
}
