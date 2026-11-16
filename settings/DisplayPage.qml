// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Layouts
import qs.components
import qs.core
import qs.services
import qs.theme

// Screen brightness and colour (services/Display.qml): the monitor's own
// settings over DDC/CI or the laptop backlight, and software colour
// (saturation, night light, gamma, dimming) through a Hyprland screen shader.
Page {
    id: page
    title: "Display"

    SettingRow {
        title: "Brightness"
        description: Display.detecting ? "Looking for screens…"
            : Display.backlight ? "The laptop screen's backlight."
            : Display.hasDdc ? "All monitors at once (each one below)."
            : "No hardware control found, so this dims the picture instead. External monitors need DDC/CI on (in the monitor's own menu), the ddcutil package and access to /dev/i2c-* (load the i2c-dev module; some distributions also need your user in the i2c group)."
        RowLayout {
            spacing: Theme.space.m
            Slider {
                implicitWidth: 200
                from: Display.hasHardware ? 0 : 20
                to: 100
                stepSize: 1
                showTicks: false
                value: Display.brightness
                onMoved: value => Display.setBrightness(value)
            }
            ValueText { text: Display.brightness + "%" }
        }
    }

    SettingRow {
        title: "Brightness button in the bar"
        description: "Scroll it to change the brightness, click it for brightness, night light and saturation."
        Toggle {
            checked: Config.display.barButton
            onToggled: value => Config.display.barButton = value
        }
    }

    // ---- One section per DDC monitor ---------------------------------------------
    Repeater {
        model: Display.monitors
        delegate: ColumnLayout {
            id: mon
            required property var modelData
            required property int index
            Layout.fillWidth: true
            spacing: Theme.space.m

            Section { text: (mon.modelData.model || "Monitor") + (mon.modelData.connector ? " · " + mon.modelData.connector : "") }

            VcpRow { title: "Brightness"; code: "10"; monitor: mon.index }
            VcpRow { title: "Contrast"; code: "12"; monitor: mon.index }

            SettingRow {
                visible: Display.vcp(mon.index, "14") >= 0
                title: "Colour preset"
                description: "The monitor's own colour temperature modes. Red, green and blue below usually only work in a User mode."
            }
            Chips {
                visible: Display.vcp(mon.index, "14") >= 0
                options: (mon.modelData.presets.length > 0 ? mon.modelData.presets : ["01", "05", "06", "08", "0b"])
                    .filter(c => Display.presetNames[c] !== undefined)
                    .map(c => ({ label: Display.presetNames[c], value: parseInt(c, 16) }))
                current: Display.vcp(mon.index, "14")
                onSelected: value => Display.setVcp(mon.index, "14", value)
            }
            VcpRow { title: "Red"; code: "16"; monitor: mon.index }
            VcpRow { title: "Green"; code: "18"; monitor: mon.index }
            VcpRow { title: "Blue"; code: "1A"; monitor: mon.index }
        }
    }

    // ---- Software colour --------------------------------------------------------------
    Section { text: "Colour" }

    StyledText {
        Layout.fillWidth: true
        text: "Done by Hyprland with a small screen shader, for what the monitor can't do itself (most monitors have no saturation setting). It is only active while something here is changed from its neutral value; then every frame goes through it (a little GPU work) and fullscreen games lose direct scanout. Screenshots don't show it."
        color: Theme.fgMuted
        font.pixelSize: Theme.font.small
        wrapMode: Text.Wrap
    }

    ColourRow {
        title: "Saturation"
        description: "Colour intensity, like NVIDIA's digital vibrance. 100 % = unchanged."
        from: 0; to: 200; value: Math.round(Display.saturation * 100)
        shown: Math.round(Display.saturation * 100) + "%"
        onMoved: v => Config.display.saturation = v / 100
    }
    ColourRow {
        title: "Night light"
        description: "Warmer colours, easier on the eyes in the evening."
        from: 0; to: 100; value: Math.round(Display.warmth * 100)
        shown: Display.warmth < 0.005 ? "Off" : Math.round(6500 - Display.warmth * 3200) + " K"
        onMoved: v => Config.display.warmth = v / 100
    }
    ColourRow {
        title: "Gamma"
        description: "Above 1 brightens dark areas, below 1 deepens them."
        from: 60; to: 160; value: Math.round(Display.gamma * 100)
        shown: Display.gamma.toFixed(2)
        onMoved: v => Config.display.gamma = v / 100
    }
    ColourRow {
        title: "Dim"
        description: "Darkens the picture below the monitor's lowest brightness."
        from: 20; to: 100; value: Math.round(Display.dim * 100)
        shown: Math.round(Display.dim * 100) + "%"
        onMoved: v => Config.display.dim = v / 100
    }
    PillButton {
        text: "Reset colour"
        enabled: Display.shaderOn
        opacity: enabled ? 1 : 0.5
        onClicked: Display.resetColour()
    }

    // ---- Pieces --------------------------------------------------------------------
    component ValueText: StyledText {
        Layout.preferredWidth: 52
        horizontalAlignment: Text.AlignRight
        color: Theme.fgMuted
        font.pixelSize: Theme.font.small
        tabular: true
    }

    // A continuous VCP feature (0–max) of one monitor; hidden if unsupported.
    component VcpRow: SettingRow {
        id: vr
        property string code
        property int monitor: 0
        readonly property int cur: Display.vcp(monitor, code)
        readonly property int max: Display.vcpMax(monitor, code)
        visible: cur >= 0
        RowLayout {
            spacing: Theme.space.m
            Slider {
                implicitWidth: 200
                from: 0
                to: vr.max
                stepSize: 1
                showTicks: false
                value: vr.cur
                onMoved: value => Display.setVcp(vr.monitor, vr.code, Math.round(value))
            }
            ValueText { text: vr.cur }
        }
    }

    component ColourRow: SettingRow {
        id: cr
        property int from: 0
        property int to: 100
        property int value: 0
        property string shown
        signal moved(int v)
        RowLayout {
            spacing: Theme.space.m
            Slider {
                implicitWidth: 200
                from: cr.from
                to: cr.to
                stepSize: 1
                showTicks: false
                value: cr.value
                onMoved: value => cr.moved(Math.round(value))
            }
            ValueText { text: cr.shown }
        }
    }
}
