// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Layouts
import qs.components
import qs.core
import qs.services
import qs.theme

// Desktop widgets: entry point to edit mode.
Page {
    title: "Widgets"

    Component.onCompleted: Cava.recheck()

    SettingRow {
        title: "Edit widgets"
        description: (Widgets.items.length === 0 ? "No widgets on your desktop yet. "
                : Widgets.items.length + (Widgets.items.length === 1 ? " widget" : " widgets") + " on your desktop. ")
            + "In edit mode: add widgets from the dock at the bottom, drag to move (Shift: no snapping), drag the corner to resize, click a widget for its style, opacity and remove buttons. SUPER + D or Escape to leave."
        PillButton {
            text: "Edit"
            onClicked: {
                // Settings would sit under the edit layer: close it first.
                ShellState.settingsOpen = false;
                Widgets.editing = true;
            }
        }
    }

    SettingRow {
        title: "Desktop menu"
        description: "Right-click the empty desktop for apps, wallpaper, widgets, recording, settings and power options."
        Toggle {
            checked: Config.desktop.menu
            onToggled: value => Config.desktop.menu = value
        }
    }

    Section { text: "Music" }

    SettingRow {
        title: "Hide when nothing plays"
        description: "Off: the widget shows a small \"Nothing playing\". Works with any player that supports MPRIS (Spotify, browsers, mpv, ...). Tip: drop a Visualizer or Equalizer right under a Music widget and it attaches."
        Toggle {
            checked: Config.widgets.musicHideIdle
            onToggled: value => Config.widgets.musicHideIdle = value
        }
    }

    Section { text: "Visualizer" }

    StyledText {
        Layout.fillWidth: true
        visible: !Cava.available && Cava.checked
        text: "The Visualizer widget needs cava, which is not installed. Install it with: sudo pacman -S cava"
        color: Theme.accent
        font.pixelSize: Theme.font.small
        wrapMode: Text.Wrap
    }

    SettingRow {
        title: "Visualizer speed"
        description: "Frames per second of the Visualizer widget. While it moves it costs CPU: here about 6–7 % of one core at 30 fps, 13–15 % at 60 (plus ~2.5 % for cava); nothing while paused or covered by windows."
        Segmented {
            options: [{ label: "20", value: 20 }, { label: "30", value: 30 }, { label: "60", value: 60 }]
            current: [20, 60].indexOf(Config.widgets.visualizerFps) !== -1 ? Config.widgets.visualizerFps : 30
            onSelected: value => Config.widgets.visualizerFps = value
        }
    }

    SettingRow {
        title: "Sensitivity"
        description: ["low", "medium", "high"].indexOf(Config.widgets.visualizerSensitivity) === -1
            ? "Auto adapts to how loud the music is, so quiet and loud songs both fill the bars."
            : "Fixed: louder music makes taller bars. Pick High if the bars stay low, Low if they hit the top all the time."
        Segmented {
            options: [{ label: "Auto", value: "auto" }, { label: "Low", value: "low" }, { label: "Medium", value: "medium" }, { label: "High", value: "high" }]
            current: ["low", "medium", "high"].indexOf(Config.widgets.visualizerSensitivity) !== -1 ? Config.widgets.visualizerSensitivity : "auto"
            onSelected: value => Config.widgets.visualizerSensitivity = value
        }
    }

    SettingRow {
        title: "Smoothing"
        description: "Snappy follows every beat; Smooth flows more calmly."
        Segmented {
            options: [{ label: "Snappy", value: "snappy" }, { label: "Balanced", value: "balanced" }, { label: "Smooth", value: "smooth" }]
            current: ["snappy", "smooth"].indexOf(Config.widgets.visualizerSmoothing) !== -1 ? Config.widgets.visualizerSmoothing : "balanced"
            onSelected: value => Config.widgets.visualizerSmoothing = value
        }
    }

    SettingRow {
        title: "Spinning disc"
        description: "In the Disc style, the record turns while music plays (20 steps a second)."
        Toggle {
            checked: Config.widgets.discSpin
            onToggled: value => Config.widgets.discSpin = value
        }
    }

    Section { text: "Equalizer" }

    SettingRow {
        title: "Music equalizer"
        description: "Only the music player's audio goes through it (" + Equalizer.presetName + "). Pick presets and drag the 6 bands in the Equalizer widget. Off or Flat: nothing is running and the audio is untouched."
        Toggle {
            checked: Equalizer.enabled
            onToggled: value => Equalizer.setEnabled(value)
        }
    }

    Section { text: "Weather" }

    SettingRow {
        id: weatherRow
        title: "Place"
        description: (Weather.configured ? "Now: " + Weather.city + ". " : "")
            + "Type a city and press Enter, then pick it. Weather comes from Open-Meteo (free, no account); only the place's coordinates are sent, and only while a Weather widget is on the desktop."

        Rectangle {
            implicitWidth: 240
            implicitHeight: 32
            radius: Theme.radius.s
            color: Theme.pressed
            border.width: 1
            border.color: cityInput.activeFocus ? Theme.accent : Theme.border

            TextInput {
                id: cityInput
                anchors.fill: parent
                anchors.leftMargin: Theme.space.s
                anchors.rightMargin: Theme.space.s
                verticalAlignment: TextInput.AlignVCenter
                color: Theme.fg
                font.family: Theme.font.family
                font.pixelSize: Theme.font.small + 1
                clip: true
                selectByMouse: true
                onAccepted: Weather.search(text)

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !cityInput.text && !cityInput.activeFocus
                    text: Weather.searching ? "Searching…" : "e.g. Milano"
                    color: Theme.fgDisabled
                    font.pixelSize: Theme.font.small + 1
                }
            }
        }
    }

    // Search results: click one to use it.
    Flow {
        Layout.fillWidth: true
        visible: Weather.results.length > 0
        spacing: Theme.space.xs
        Repeater {
            model: Weather.results
            PillButton {
                required property var modelData
                text: modelData.name + (modelData.region ? " · " + modelData.region : "")
                onClicked: {
                    Weather.choose(modelData);
                    cityInput.text = "";
                }
            }
        }
    }

    SettingRow {
        title: "Units"
        Segmented {
            options: [{ label: "°C", value: "c" }, { label: "°F", value: "f" }]
            current: Config.widgets.weatherUnits === "f" ? "f" : "c"
            onSelected: value => Config.widgets.weatherUnits = value
        }
    }

    Section { text: "System" }

    SettingRow {
        title: "GPU temperature"
        description: "Shown in the System widget. Read with nvidia-smi every 5 s, only while the widget is on the desktop (NVIDIA cards only)."
        Toggle {
            checked: Config.widgets.gpuTemp
            onToggled: value => Config.widgets.gpuTemp = value
        }
    }
}
