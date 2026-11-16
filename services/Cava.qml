// SPDX-License-Identifier: GPL-3.0-or-later
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.core
import qs.theme

// Audio spectrum for the music visualizer, from cava (optional dependency).
//
// cava runs ONLY while: a visualizer is shown and not covered by windows
// (`users` > 0), something is playing, and the focused workspace is not
// fullscreen. Otherwise it is stopped (no process, no CPU). Its raw output
// (one line of `bars` numbers 0–100 per frame) becomes `values` (0–1).
Singleton {
    id: root

    property int users: 0
    readonly property int bars: 28
    readonly property int fps: Config.ready && [20, 30, 60].indexOf(Config.widgets.visualizerFps) !== -1 ? Config.widgets.visualizerFps : 30
    // Shown if a music widget has the visualizer on, or a Visualizer widget exists.
    readonly property bool enabled: users > 0
    // Sensitivity: "auto" adapts to the loudness (cava's autosens); the fixed
    // levels don't, so quiet and loud songs look different.
    readonly property string sensitivity: Config.ready ? Config.widgets.visualizerSensitivity : "auto"
    // How quickly the bars follow the music (cava's noise reduction).
    readonly property string smoothing: Config.ready ? Config.widgets.visualizerSmoothing : "balanced"
    readonly property string tuning: fps + sensitivity + smoothing
    // New settings: restart cava with a new config once the old one has
    // exited (it doesn't stop instantly).
    property bool restartPending: false
    onTuningChanged: if (proc.running) { restartPending = true; proc.running = false; }
    readonly property bool paused: Hyprland.focusedMonitor?.activeWorkspace?.hasFullscreen ?? false

    // Whether `cava` is installed (checked once, when first needed).
    property bool available: false
    property bool checked: false

    readonly property bool wanted: users > 0 && enabled && Media.playing && !paused
    onWantedChanged: update()

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
            settle();
        }
    }

    // Stopped (paused, covered...): the bars sink to rest over ~0.5 s
    // instead of dropping at once. Runs at the visualizer's fps, then stops.
    function settle(): void {
        if (values.length > 0 && Theme.animations)
            decay.start();
        else
            values = [];
    }
    Timer {
        id: decay
        interval: Math.round(1000 / root.fps)
        repeat: true
        onTriggered: {
            if (proc.running) {
                stop();
                return;
            }
            const next = root.values.map(v => Math.max(0, v * 0.8 - 0.012));
            if (next.every(v => v <= 0.005)) {
                root.values = [];
                stop();
            } else {
                root.values = next;
            }
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
            "autosens = " + (sensitivity === "auto" || ["low", "medium", "high"].indexOf(sensitivity) === -1 ? 1 : 0),
            "sensitivity = " + ({ low: 60, medium: 120, high: 250 }[sensitivity] ?? 100),
            "lower_cutoff_freq = 50",
            "higher_cutoff_freq = 12000",
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
            // Mono (both channels averaged): steadier bars, left to right
            // from bass to treble.
            "channels = mono",
            "mono_option = average",
            "[smoothing]",
            "noise_reduction = " + ({ snappy: 35, smooth: 88 }[smoothing] ?? 68),
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
                decay.stop();
                root.values = out;
            }
        }
        onExited: code => {
            if (!root.restartPending)
                root.settle();
            if (root.restartPending) {
                root.restartPending = false;
                root.update();
            } else if (code !== 0 && root.wanted) {
                console.warn("altair: cava exited with code " + code);
            }
        }
    }
}
