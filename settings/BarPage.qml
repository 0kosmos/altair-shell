// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Layouts
import qs.components
import qs.core
import qs.services
import qs.theme

Page {
    title: "Bar"

    Component.onCompleted: Recorder.recheck()

    SettingRow {
        title: "Position"
        Segmented {
            options: [{ label: "Top", value: "top" }, { label: "Bottom", value: "bottom" },
                      { label: "Left", value: "left" }, { label: "Right", value: "right" }]
            current: Theme.barPosition
            onSelected: value => Config.appearance.barPosition = value
        }
    }

    SettingRow {
        title: "Move by dragging"
        description: "Press on an empty spot of the bar and drag it to another edge of the screen. Off: only the choice above moves it."
        Toggle {
            checked: Config.bar.dragToMove
            onToggled: value => Config.bar.dragToMove = value
        }
    }

    Section { text: "Screen recorder" }

    SettingRow {
        title: "Record button"
        description: Recorder.available || !Recorder.checked
            ? "Click it to record the screen you are on at 60 fps, click again to save. Encoded on the graphics card, so it barely uses the CPU. Saved to " + Recorder.folder.replace(/^\/home\/[^/]+/, "~") + "."
            : "Needs gpu-screen-recorder, which is not installed: sudo pacman -S gpu-screen-recorder"
        Toggle {
            checked: Config.recorder.showButton
            onToggled: value => Config.recorder.showButton = value
        }
    }

    SettingRow {
        title: "Sound"
        description: "Record the computer's sound, and optionally your microphone too."
        Segmented {
            options: [{ label: "Off", value: "none" }, { label: "System", value: "system" }, { label: "System + mic", value: "both" }]
            current: ["none", "both"].indexOf(Config.recorder.audio) !== -1 ? Config.recorder.audio : "system"
            onSelected: value => Config.recorder.audio = value
        }
    }

    Section { text: "Workspaces" }

    SettingRow {
        title: "Always show"
        description: "Number of workspace dots shown even when empty. Higher workspaces appear when in use."
        RowLayout {
            spacing: Theme.space.m
            Slider {
                implicitWidth: 160
                from: 1
                to: 10
                value: Config.bar.workspaces
                onMoved: value => Config.bar.workspaces = value
            }
            StyledText {
                Layout.preferredWidth: 24
                text: Config.bar.workspaces
                color: Theme.fgMuted
                font.pixelSize: Theme.font.small
                tabular: true
            }
        }
    }

    Section { text: "Clock" }

    SettingRow {
        title: "Position"
        description: Theme.barVertical
            ? "Top first: above the workspaces. Top: below them. Bottom: above the status buttons. Bottom last: at the very end."
            : "Left first: before the workspaces. Left: after them. Right: before the status buttons. Right last: after them."
    }
    Chips {
        Layout.bottomMargin: Theme.space.s
        options: Theme.barVertical
            ? [{ label: "Top first", value: "leftFirst" }, { label: "Top", value: "left" }, { label: "Middle", value: "center" },
               { label: "Bottom", value: "right" }, { label: "Bottom last", value: "rightLast" }]
            : [{ label: "Left first", value: "leftFirst" }, { label: "Left", value: "left" }, { label: "Middle", value: "center" },
               { label: "Right", value: "right" }, { label: "Right last", value: "rightLast" }]
        current: Config.bar.clockPosition
        onSelected: value => Config.bar.clockPosition = value
    }

    SettingRow {
        title: "Show date"
        description: "The date next to the time. The format follows your system's locale."
        Toggle {
            checked: Config.bar.showDate
            onToggled: value => Config.bar.showDate = value
        }
    }

    SettingRow {
        title: "Calendar on click"
        description: "Click the clock for a month calendar. Arrows or the mouse wheel change the month; click the month name to go back to today."
        Toggle {
            checked: Config.bar.clockPopup
            onToggled: value => Config.bar.clockPopup = value
        }
    }

    SettingRow {
        title: "Week numbers"
        description: "ISO week numbers in the calendar."
        enabled: Config.bar.clockPopup
        opacity: enabled ? 1 : 0.5
        Toggle {
            checked: Config.bar.weekNumbers
            onToggled: value => Config.bar.weekNumbers = value
        }
    }

    SettingRow {
        title: "Round clock in calendar"
        description: "An analogue clock next to the calendar."
        enabled: Config.bar.clockPopup
        opacity: enabled ? 1 : 0.5
        Toggle {
            checked: Config.bar.analogClock
            onToggled: value => Config.bar.analogClock = value
        }
    }

    SettingRow {
        title: "Seconds hand"
        description: "Ticks once a second, only while the calendar is open."
        enabled: Config.bar.clockPopup && Config.bar.analogClock
        opacity: enabled ? 1 : 0.5
        Toggle {
            checked: Config.bar.clockSeconds
            onToggled: value => Config.bar.clockSeconds = value
        }
    }

    Section { text: "Buttons" }

    SettingRow {
        title: "Bluetooth"
        description: Bt.available ? "The Bluetooth button and menu." : "No Bluetooth adapter found (or the bluetooth service is not running), so the button is hidden anyway."
        Toggle {
            checked: Config.bar.bluetooth
            onToggled: value => Config.bar.bluetooth = value
        }
    }

    SettingRow {
        title: "Quick settings button"
        description: "Wi-Fi, Bluetooth, do not disturb, night light, volume and more in one panel (also SUPER + A)."
        Toggle {
            checked: Config.bar.quickSettings
            onToggled: value => Config.bar.quickSettings = value
        }
    }
}
