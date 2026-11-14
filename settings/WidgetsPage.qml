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

    Section { text: "Music" }

    SettingRow {
        title: "Hide when nothing plays"
        description: "Off: the widget shows a small \"Nothing playing\". Works with any player that supports MPRIS (Spotify, browsers, mpv, ...)."
        Toggle {
            checked: Config.widgets.musicHideIdle
            onToggled: value => Config.widgets.musicHideIdle = value
        }
    }

    SettingRow {
        title: "Visualizer"
        description: !Cava.available && Cava.checked
            ? "Needs cava, which is not installed. Install it with: sudo pacman -S cava"
            : "Bars that move with the music, under the Card and Disc styles. Runs only while something plays. Uses some CPU (about 3.5 % of one core at 30 fps here)."
        Segmented {
            enabled: Cava.available || !Cava.checked
            opacity: enabled ? 1 : 0.5
            options: [{ label: "Off", value: "off" }, { label: "Bars", value: "bars" }, { label: "Mirror", value: "mirror" }, { label: "Wave", value: "wave" }]
            current: ["bars", "mirror", "wave"].indexOf(Config.widgets.visualizer) !== -1 ? Config.widgets.visualizer : "off"
            onSelected: value => Config.widgets.visualizer = value
        }
    }

    SettingRow {
        title: "Visualizer speed"
        description: "Frames per second. Smoother costs more CPU."
        enabled: Config.widgets.visualizer !== "off"
        opacity: enabled ? 1 : 0.5
        Segmented {
            options: [{ label: "20", value: 20 }, { label: "30", value: 30 }, { label: "60", value: 60 }]
            current: [20, 60].indexOf(Config.widgets.visualizerFps) !== -1 ? Config.widgets.visualizerFps : 30
            onSelected: value => Config.widgets.visualizerFps = value
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
