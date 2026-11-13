// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Layouts
import qs.components
import qs.core
import qs.services
import qs.theme

Page {
    title: "Wallpaper"

    SettingRow {
        title: "Wallpaper"
        description: Wallpapers.current ? Wallpapers.pretty(Wallpapers.current) : "Hyprland's own background (Altair draws none)."
        RowLayout {
            spacing: Theme.space.s
            PillButton {
                visible: Wallpapers.current !== ""
                text: "Use Hyprland's"
                onClicked: Wallpapers.set("")
            }
            PillButton {
                text: "Choose…"
                onClicked: ShellState.open("wallpaper")
            }
        }
    }

    SettingRow {
        title: "Fit"
        description: "Fill crops the picture to cover the screen; Fit shows all of it, with bars if the shape differs."
        Segmented {
            options: [{ label: "Fill", value: "crop" }, { label: "Fit", value: "fit" }]
            current: Wallpapers.fill
            onSelected: value => Config.wallpaper.fill = value
        }
    }

    SettingRow {
        title: "Folder"
        description: "Where the picker looks for images and videos. Press Enter to apply."

        Rectangle {
            implicitWidth: 240
            implicitHeight: 32
            radius: Theme.radius.s
            color: Theme.pressed
            border.width: 1
            border.color: folderInput.activeFocus ? Theme.accent : Theme.border

            TextInput {
                id: folderInput
                anchors.fill: parent
                anchors.leftMargin: Theme.space.s
                anchors.rightMargin: Theme.space.s
                verticalAlignment: TextInput.AlignVCenter
                text: Wallpapers.pretty(Wallpapers.folder)
                color: Theme.fg
                font.family: Theme.font.family
                font.pixelSize: Theme.font.small + 1
                clip: true
                selectByMouse: true
                onAccepted: {
                    Config.wallpaper.folder = text.trim();
                    focus = false;
                }
            }
        }
    }

    Section { text: "Picker (SUPER + W)" }

    SettingRow {
        title: "Style"
        description: Config.wallpaper.picker === "grid" ? "A centred panel with a grid of thumbnails."
            : "A carousel with the selected wallpaper in the middle. Hover or scroll to preview, click to apply."
        Segmented {
            options: [{ label: "Strip", value: "strip" }, { label: "Grid", value: "grid" }]
            current: Config.wallpaper.picker === "grid" ? "grid" : "strip"
            onSelected: value => Config.wallpaper.picker = value
        }
    }

    SettingRow {
        title: "Strip position"
        enabled: Config.wallpaper.picker !== "grid"
        opacity: enabled ? 1 : 0.4
        Segmented {
            options: [{ label: "Bottom", value: "bottom" }, { label: "Centre", value: "center" }, { label: "Top", value: "top" }]
            current: ["top", "center"].includes(Config.wallpaper.pickerPosition) ? Config.wallpaper.pickerPosition : "bottom"
            onSelected: value => Config.wallpaper.pickerPosition = value
        }
    }

    Section { text: "Live wallpapers (videos)" }

    StyledText {
        Layout.fillWidth: true
        text: "Videos (MP4, WebM, MKV) play in a separate background process, so the rest of Altair stays light. "
            + "While playing, that costs roughly 250–350 MB of memory and a little CPU; paused, the CPU use drops to about zero. "
            + "Switching to a picture ends the process and frees the memory."
        color: Theme.fgMuted
        font.pixelSize: Theme.font.small
        wrapMode: Text.Wrap
    }

    SettingRow {
        title: "Play live wallpapers"
        description: Theme.lowPower ? "Paused by low-power mode: a still frame is shown." : "Off: a still frame of the video is shown instead."
        Toggle {
            checked: Config.wallpaper.live.enabled
            onToggled: value => Config.wallpaper.live.enabled = value
        }
    }

    SettingRow {
        title: "Speed"
        description: "Playback speed of live wallpapers."
        RowLayout {
            spacing: Theme.space.m
            Slider {
                implicitWidth: 160
                from: 0.25
                to: 2
                stepSize: 0.25
                value: Wallpapers.speed
                onMoved: value => Config.wallpaper.live.speed = value
            }
            StyledText {
                Layout.preferredWidth: 40
                text: Wallpapers.speed.toFixed(2).replace(/0$/, "") + "×"
                color: Theme.fgMuted
                font.pixelSize: Theme.font.small
                tabular: true
            }
        }
    }

    SettingRow {
        title: "Pause when"
        description: Config.wallpaper.live.pauseWhen === "never" ? "Always playing."
            : Config.wallpaper.live.pauseWhen === "fullscreen" ? "Pauses while a fullscreen window is on screen."
            : "Pauses while any window is open on the visible workspace; plays on an empty desktop."
        Segmented {
            options: [{ label: "Window open", value: "window" }, { label: "Fullscreen", value: "fullscreen" }, { label: "Never", value: "never" }]
            current: Config.wallpaper.live.pauseWhen
            onSelected: value => Config.wallpaper.live.pauseWhen = value
        }
    }
}
