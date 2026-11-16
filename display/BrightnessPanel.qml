// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Layouts
import qs.components
import qs.core
import qs.services
import qs.theme

// Brightness popup from the bar's brightness button (or
// `qs -c altair ipc call panels toggle brightness`): brightness, night light
// and saturation, plus a link to Settings > Display for the rest.
AltairPanel {
    id: root

    name: "brightness"
    dock: Theme.barVertical ? Theme.barPosition : Theme.barAtTop ? "top" : "bottom"
    centerVertically: Theme.barVertical
    fullWidth: false
    along: "end"
    slideDistance: 12
    panelWidth: 340
    property real contentHeight: 240
    panelHeight: contentHeight

    content: Component {
        FocusScope {
            focus: true
            Binding {
                target: root
                property: "contentHeight"
                value: col.implicitHeight + Theme.space.l * 2
            }

            ColumnLayout {
                id: col
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Theme.space.l
                spacing: Theme.space.m

                RowLayout {
                    Layout.fillWidth: true
                    StyledText {
                        Layout.fillWidth: true
                        text: "Display"
                        font.pixelSize: Theme.font.title
                        font.weight: Font.DemiBold
                    }
                    IconButton {
                        visible: Display.shaderOn
                        icon: "restart_alt"
                        onClicked: Display.resetColour()
                    }
                    IconButton {
                        icon: "settings"
                        onClicked: {
                            ShellState.close();
                            ShellState.openSettings("display");
                        }
                    }
                }

                SliderRow {
                    icon: Display.icon
                    label: "Brightness"
                    from: Display.hasHardware ? 0 : 20
                    value: Display.brightness
                    shown: Display.brightness + "%"
                    onMoved: v => Display.setBrightness(v)
                }
                SliderRow {
                    icon: "nightlight"
                    label: "Night light"
                    value: Math.round(Display.warmth * 100)
                    shown: Display.warmth < 0.005 ? "Off" : Math.round(6500 - Display.warmth * 3200) + " K"
                    onMoved: v => Config.display.warmth = v / 100
                }
                SliderRow {
                    icon: "palette"
                    label: "Saturation"
                    to: 200
                    value: Math.round(Display.saturation * 100)
                    shown: Math.round(Display.saturation * 100) + "%"
                    onMoved: v => Config.display.saturation = v / 100
                }

                StyledText {
                    visible: !Display.hasHardware && !Display.detecting
                    Layout.fillWidth: true
                    text: "No brightness control found for this screen, so brightness dims the picture instead (Settings > Display explains why)."
                    color: Theme.fgDisabled
                    font.pixelSize: Theme.font.small
                    wrapMode: Text.Wrap
                }
            }
        }
    }

    component SliderRow: ColumnLayout {
        id: sr
        property string icon
        property string label
        property string shown
        property int from: 0
        property int to: 100
        property int value: 0
        signal moved(int v)
        Layout.fillWidth: true
        spacing: 2
        RowLayout {
            Layout.fillWidth: true
            Icon {
                name: sr.icon
                size: 16
                color: Theme.fgMuted
            }
            StyledText {
                Layout.fillWidth: true
                text: sr.label
                font.pixelSize: Theme.font.small
            }
            StyledText {
                text: sr.shown
                color: Theme.fgMuted
                font.pixelSize: Theme.font.small
                tabular: true
            }
        }
        Slider {
            Layout.fillWidth: true
            from: sr.from
            to: sr.to
            stepSize: 1
            showTicks: false
            value: sr.value
            onMoved: v => sr.moved(v)
        }
    }
}
