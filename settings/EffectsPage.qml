// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Layouts
import qs.components
import qs.core
import qs.theme

Page {
    id: page
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
        description: "Colour, texture or gentle motion on panels and menus, from your accent colour (or palette). Moving styles only move while a panel or menu is open; the bar, dock and Settings show them still, so nothing runs while idle."
    }

    // Live preview (moves while this page is shown).
    Item {
        Layout.fillWidth: true
        Layout.preferredHeight: 128
        Rectangle {
            anchors.fill: parent
            radius: Theme.radius.m
            color: Theme.dark ? "#0b0c10" : "#d9dbe2"
        }
        GlassBackground {
            id: previewGlass
            anchors.centerIn: parent
            width: Math.min(parent.width - 32, 420)
            height: 100
            radius: Theme.radius.l
            animate: page.visible
            StyledText {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.margins: Theme.space.l
                text: Theme.panelStyles[Theme.panelFx].replace(/^./, c => c.toUpperCase())
                font.pixelSize: Theme.font.title
                font.weight: Font.DemiBold
            }
            StyledText {
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                anchors.margins: Theme.space.l
                text: Theme.panelFx >= 10 ? (Theme.panelFxAnimated ? "Moves while a panel is open" : "Still (animation off)") : "Still"
                color: Theme.fgMuted
                font.pixelSize: Theme.font.small
            }
        }
    }

    StyledText {
        text: "Still"
        color: Theme.fgMuted
        font.pixelSize: Theme.font.small
    }
    Chips {
        options: [{ label: "None", value: "none" }, { label: "Glow", value: "glow" }, { label: "Aurora", value: "aurora" },
                  { label: "Grain", value: "grain" }, { label: "Mesh", value: "mesh" }, { label: "Sheen", value: "sheen" },
                  { label: "Edge light", value: "edge" }, { label: "Dusk", value: "dusk" }, { label: "Lines", value: "lines" },
                  { label: "Dots", value: "dots" }]
        current: Theme.panelStyles.indexOf(Config.effects.panelStyle) > 0 ? Config.effects.panelStyle : "none"
        onSelected: value => Config.effects.panelStyle = value
    }
    StyledText {
        text: "Moving"
        color: Theme.fgMuted
        font.pixelSize: Theme.font.small
    }
    Chips {
        Layout.bottomMargin: Theme.space.s
        options: [{ label: "Flow", value: "flow" }, { label: "Nebula", value: "nebula" }, { label: "Waves", value: "waves" },
                  { label: "Prism", value: "prism" }, { label: "Stars", value: "stars" }, { label: "Pulse", value: "pulse" }]
        current: Config.effects.panelStyle
        onSelected: value => Config.effects.panelStyle = value
    }

    SettingRow {
        title: "Intensity"
        description: "How strong the background shows."
        RowLayout {
            spacing: Theme.space.m
            Slider {
                Layout.preferredWidth: 200
                from: 30
                to: 160
                stepSize: 10
                showTicks: false
                value: Math.round(Theme.panelIntensity * 100)
                onMoved: v => Config.effects.panelIntensity = v / 100
            }
            StyledText {
                Layout.preferredWidth: 44
                horizontalAlignment: Text.AlignRight
                text: Math.round(Theme.panelIntensity * 100) + "%"
                color: Theme.fgMuted
                tabular: true
            }
        }
    }
    SettingRow {
        title: "Colours"
        description: Theme.usingPalette ? "Shades of the accent, or the colours of your palette." : "Shades of the accent. Choose a palette in Appearance to use its colours."
        Segmented {
            options: [{ label: "Accent", value: "accent" }, { label: "Palette", value: "palette" }]
            current: Config.effects.panelColors
            onSelected: value => Config.effects.panelColors = value
        }
    }
    SettingRow {
        title: "Animate moving styles"
        description: "Off shows them still. Moving costs some CPU while a panel is open (30 frames a second), nothing otherwise."
        Toggle {
            checked: Config.effects.panelAnimate
            onToggled: value => Config.effects.panelAnimate = value
        }
    }
    SettingRow {
        title: "Speed"
        Segmented {
            options: [{ label: "Slow", value: 0.5 }, { label: "Normal", value: 1 }, { label: "Fast", value: 2 }]
            current: Config.effects.panelSpeed
            onSelected: value => Config.effects.panelSpeed = value
        }
    }
    SettingRow {
        title: "Panel motion"
        description: "How panels and menus open and close."
        Segmented {
            options: [{ label: "Glide", value: "glide" }, { label: "Spring", value: "spring" }, { label: "Zoom", value: "zoom" },
                      { label: "Drop", value: "drop" }, { label: "Fade", value: "fade" }]
            current: Theme.panelMotion
            onSelected: value => {
                Config.effects.panelMotion = value;
                // Show it: open and close the calendar once.
                demoMotion.restart();
            }
        }
    }
    Timer {
        id: demoMotion
        interval: 250
        onTriggered: {
            ShellState.open("calendar");
            demoClose.restart();
        }
    }
    Timer {
        id: demoClose
        interval: 1100
        onTriggered: if (ShellState.openPanel === "calendar") ShellState.close()
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
