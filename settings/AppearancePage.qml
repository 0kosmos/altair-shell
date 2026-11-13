// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Layouts
import qs.components
import qs.core
import qs.services
import qs.theme

Page {
    id: page
    title: "Appearance"

    // Preset accents. "mono" is monochrome: near-white on dark, dark grey on light.
    readonly property var swatches: ["#7aa2f7", "#bb9af7", "#7dcfff", "#73daca", "#9ece6a", "#e0af68", "#ff9e64", "#f7768e", "mono"]

    SettingRow {
        title: "Theme"
        Segmented {
            options: [{ label: "Dark", value: "dark" }, { label: "Light", value: "light" }]
            current: Config.appearance.theme === "light" ? "light" : "dark"
            onSelected: value => Config.appearance.theme = value
        }
    }

    SettingRow {
        title: "Bar position"
        Segmented {
            options: [{ label: "Top", value: "top" }, { label: "Bottom", value: "bottom" }]
            current: Theme.barPosition
            onSelected: value => Config.appearance.barPosition = value
        }
    }

    SettingRow {
        title: "Window borders"
        description: Hypr.borderMode === "accent" ? "The focused window gets the accent colour, others a soft grey."
            : Hypr.borderMode === "none" ? "No borders around windows."
            : "The colours and size from your Hyprland config."
        Segmented {
            options: [{ label: "Accent", value: "accent" }, { label: "Hyprland", value: "hyprland" }, { label: "None", value: "none" }]
            current: Hypr.borderMode
            onSelected: value => Config.appearance.windowBorders = value
        }
    }

    Section { text: "Accent colour" }

    readonly property string accentSetting: Config.appearance.accent.toLowerCase()
    readonly property bool customAccent: swatches.indexOf(accentSetting) === -1
    property bool pickerOpen: false

    Flow {
        Layout.fillWidth: true
        spacing: Theme.space.s

        Repeater {
            model: page.swatches

            Swatch {
                required property string modelData
                fillColor: modelData === "mono" ? Theme.monoColor : modelData
                selected: page.accentSetting === modelData
                onClicked: Config.appearance.accent = modelData
            }
        }

        // Custom colour: shows the colour when it isn't one of the presets.
        // The pipette stays visible on top, so it's always findable.
        // Opens the picker below.
        Swatch {
            fillColor: page.customAccent ? Theme.chosenAccent : Theme.pressed
            selected: page.customAccent || page.pickerOpen
            onClicked: {
                if (!page.pickerOpen)
                    picker.load(Theme.chosenAccent);
                page.pickerOpen = !page.pickerOpen;
            }

            Icon {
                anchors.centerIn: parent
                name: "colorize"
                size: 15
                // Readable on any fill: dark or light, whichever contrasts more.
                color: !page.customAccent ? Theme.fgMuted
                    : Theme.contrast(Theme.chosenAccent, "#111216") > Theme.contrast(Theme.chosenAccent, "#ffffff") ? "#111216" : "#ffffff"
                opacity: page.customAccent ? 0.85 : 1
            }
        }
    }

    // The picker unfolds under the swatches.
    Item {
        Layout.fillWidth: true
        implicitHeight: page.pickerOpen ? picker.implicitHeight + Theme.space.s : 0
        clip: true
        opacity: page.pickerOpen ? 1 : 0

        Behavior on implicitHeight {
            NumberAnimation { duration: Theme.anim.normal; easing.type: Theme.anim.easingSlide }
        }
        Behavior on opacity {
            NumberAnimation { duration: Theme.anim.normal }
        }

        ColorPicker {
            id: picker
            width: Math.min(parent.width, 420)
            y: Theme.space.xs

            // Live while dragging, but at most every 90 ms: every accent change
            // re-colours the shell, rewrites the config file and (with accent
            // borders) updates Hyprland.
            property color pending
            onChanged: (value, final) => {
                pending = value;
                if (final) {
                    throttle.stop();
                    page.applyAccent(value);
                } else if (!throttle.running) {
                    throttle.start();
                }
            }
            Timer {
                id: throttle
                interval: 90
                onTriggered: page.applyAccent(picker.pending)
            }
        }
    }

    function applyAccent(c: color): void {
        Config.appearance.accent = picker.hex(c);
    }

    component Swatch: MouseArea {
        id: swatch
        property color fillColor
        property bool selected: false

        width: 32
        height: 32
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true
        scale: pressed ? Theme.anim.pressScale : 1
        Behavior on scale {
            NumberAnimation { duration: Theme.anim.fast; easing.type: Easing.OutBack; easing.overshoot: 2.5 }
        }

        // Ring around the selected colour.
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: "transparent"
            border.width: 2
            border.color: swatch.selected ? Theme.fg : swatch.containsMouse ? Theme.fgDisabled : "transparent"
            Behavior on border.color {
                ColorAnimation { duration: Theme.anim.fast }
            }
        }
        Rectangle {
            anchors.centerIn: parent
            width: 22
            height: 22
            radius: 11
            color: swatch.fillColor
            Behavior on color {
                ColorAnimation { duration: Theme.anim.fast }
            }
        }
    }
}
