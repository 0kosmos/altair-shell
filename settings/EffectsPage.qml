// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Layouts
import qs.components
import qs.core
import qs.theme

Page {
    title: "Effects"

    StyledText {
        Layout.fillWidth: true
        visible: Theme.lowPower
        text: "Low-power mode is on, so blur, liquid glass and animations are paused. Turn it off under Performance."
        color: Theme.accent
        font.pixelSize: Theme.font.small
        wrapMode: Text.Wrap
    }

    Section { text: "Blur" }

    SettingRow {
        title: "Blur behind panels"
        description: "Frosted background for the bar, launcher, popups and menus. Drawn by Hyprland."
        Toggle {
            checked: Config.effects.blur
            onToggled: value => Config.effects.blur = value
        }
    }

    SettingRow {
        title: "Blur strength"
        description: Config.effects.blurStrength < 1
            ? "Using Hyprland's own setting. Hyprland has one blur setting for everything, so changing this also changes window blur."
            : "Also applies to your windows: Hyprland has one blur setting for everything. Move fully left to go back to Hyprland's own setting."

        RowLayout {
            spacing: Theme.space.m

            Slider {
                implicitWidth: 160
                from: 0
                to: 10
                value: Math.max(0, Config.effects.blurStrength)
                onMoved: value => Config.effects.blurStrength = value < 1 ? -1 : value
            }
            StyledText {
                Layout.preferredWidth: 64
                text: Config.effects.blurStrength < 1 ? "Hyprland" : Config.effects.blurStrength
                color: Theme.fgMuted
                font.pixelSize: Theme.font.small
                tabular: true
            }
        }
    }

    Section { text: "Look" }

    SettingRow {
        title: "Liquid glass"
        description: "Gradient tint, a bright edge highlight and a soft inner glow on Altair's panels. The background is blurred, not bent: real refraction would need compositor support."
        Toggle {
            checked: Config.effects.liquidGlass
            onToggled: value => Config.effects.liquidGlass = value
        }
    }

    SettingRow {
        title: "Panel backgrounds"
        description: "A touch of colour or texture on panels, menus, Settings, the bar and the dock, from your accent colour. Drawn once, so it costs nothing while idle."
    }
    Chips {
        Layout.bottomMargin: Theme.space.s
        options: [{ label: "None", value: "none" }, { label: "Glow", value: "glow" }, { label: "Aurora", value: "aurora" },
                  { label: "Grain", value: "grain" }, { label: "Mesh", value: "mesh" }, { label: "Sheen", value: "sheen" },
                  { label: "Edge light", value: "edge" }, { label: "Dusk", value: "dusk" }, { label: "Lines", value: "lines" },
                  { label: "Dots", value: "dots" }]
        current: Theme.panelStyles.indexOf(Config.effects.panelStyle) > 0 ? Config.effects.panelStyle : "none"
        onSelected: value => Config.effects.panelStyle = value
    }

    SettingRow {
        title: "Search animations"
        description: "How the launcher's results move while you type: new matches slide in, others fade out and the list glides into place. Lively staggers them a little."
        Segmented {
            options: [{ label: "Off", value: "off" }, { label: "Subtle", value: "subtle" }, { label: "Lively", value: "lively" }]
            current: Theme.searchAnim === "off" && !Theme.lowPower ? "off" : Config.effects.searchAnimations
            onSelected: value => Config.effects.searchAnimations = value
        }
    }

    SettingRow {
        title: "Animations"
        description: "Fades and slides when things open, close or change."
        Toggle {
            checked: Config.effects.animations
            onToggled: value => Config.effects.animations = value
        }
    }
}
