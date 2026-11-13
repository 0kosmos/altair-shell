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
        title: "Animations"
        description: "Fades and slides when things open, close or change."
        Toggle {
            checked: Config.effects.animations
            onToggled: value => Config.effects.animations = value
        }
    }
}
