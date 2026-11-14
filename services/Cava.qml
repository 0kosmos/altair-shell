// SPDX-License-Identifier: GPL-3.0-or-later
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.core

// Audio spectrum for the music visualizer, from cava (optional dependency).
//
// cava runs ONLY while: a visualizer is shown (`users` > 0), the visualizer is
// on (Settings > Widgets), something is playing, and the focused workspace is
// not fullscreen. Otherwise it is stopped (no process, no CPU). Its raw output
// (one line of `bars` numbers 0–100 per frame) becomes `values` (0–1).
Singleton {
    id: root

    property int users: 0
    readonly property int bars: 28
    readonly property int fps: Config.ready && [20, 30, 60].indexOf(Config.widgets.visualizerFps) !== -1 ? Config.widgets.visualizerFps : 30
    readonly property bool enabled: Config.ready && Config.widgets.visualizer !== "off"
    readonly property bool paused: Hyprland.focusedMonitor?.activeWorkspace?.hasFullscreen ?? false

    // Whether `cava` is installed (checked once, when first needed).
    property bool available: false
    property bool checked: false

    readonly property bool wanted: users > 0 && enabled && Media.playing && !paused
    onWantedChanged: update()
    onFpsChanged: if (proc.running) { proc.running = false; Qt.callLater(update); }

    property var values: []

    // Look for cava again (Settings page opened: it may have been installed).
    function recheck(): void {
        if (!check.running)
            check.running = true;
    }

    function update(): void {
        if (wanted && !checked) {
            check.running = true;
            return;
        }
        if (wanted && available && !proc.running) {
            writeConfig();
            proc.running = true;
        } else if (!wanted && proc.running) {
            proc.running = false;
            values = [];
        }
    }

    Process {
        id: check
        command: ["sh", "-c", "command -v cava"]
        onExited: code => {
            root.available = code === 0;
            root.checked = true;
            if (!root.available)
                console.info("altair: cava not found, the music visualizer is disabled (install the 'cava' package)");
            root.update();
        }
    }

    readonly property string confPath: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/altair-cava.conf"

    function writeConfig(): void {
        conf.setText([
            "[general]",
            "framerate = " + fps,
            "bars = " + bars,
            "autosens = 1",
            "[input]",
            "method = pipewire",
            "source = auto",
            "[output]",
            "method = raw",
            "raw_target = /dev/stdout",
            "data_format = ascii",
            "ascii_max_range = 100",
            "bar_delimiter = 59",
            "frame_delimiter = 10",
            "[smoothing]",
            "noise_reduction = 70",
            ""
        ].join("\n"));
    }

    FileView {
        id: conf
        path: root.confPath
        blockWrites: true
        printErrors: false   // written before use; never read
    }

    Process {
        id: proc
        command: ["cava", "-p", root.confPath]
        stdout: SplitParser {
            onRead: line => {
                const v = line.split(";");
                const out = [];
                for (let i = 0; i < root.bars && i < v.length; i++)
                    out.push((parseInt(v[i]) || 0) / 100);
                root.values = out;
            }
        }
        onExited: code => {
            root.values = [];
            if (code !== 0 && root.wanted)
                console.warn("altair: cava exited with code " + code);
        }
    }
}
