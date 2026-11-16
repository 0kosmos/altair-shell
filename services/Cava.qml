// SPDX-License-Identifier: GPL-3.0-or-later
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Pipewire
import qs.core
import qs.theme

// Audio spectrum for the music visualizer, from cava (optional dependency).
//
// cava runs ONLY while: a visualizer is shown and not covered by windows
// (`users` > 0), something is playing, and the focused workspace is not
// fullscreen. Otherwise it is stopped (no process, no CPU). Its raw output
// (one line of `bars` numbers 0–100 per frame) becomes `values` (0–1).
//
// It hears only the music player: cava's own PipeWire input can only record
// a device or the whole speaker output (with UI and notification sounds), so
// it starts unconnected (node "altair-cava", autoconnect off) and
// `pw-link` wires the player's output stream(s) straight into it. If the
// player's stream can't be found, it falls back to the whole output.
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

    // The player's audio streams in PipeWire (node names), matched like the
    // player volume in Media.qml. Links follow when they change; another
    // player means a fresh cava (its old links go with it).
    readonly property var playerStreams: {
        const p = Media.player;
        if (!p)
            return [];
        const names = [p.identity, p.desktopEntry, Media.appName].filter(n => n).map(n => String(n).toLowerCase());
        const nodes = (Pipewire.nodes?.values ?? []).filter(n => {
            if (!n.isStream || n.isSink)
                return false;
            const pr = n.properties ?? {};
            const app = String(pr["application.name"] ?? "").toLowerCase();
            const bin = String(pr["application.process.binary"] ?? "").toLowerCase();
            return names.some(x => x && (app === x || bin === x || app.includes(x) || (x.includes(app) && app.length > 2)));
        });
        return [...new Set(nodes.map(n => n.name).filter(n => n))].sort();
    }
    readonly property string streamKey: playerStreams.join(",")
    onStreamKeyChanged: if (proc.running) linkTimer.restart()
    property var startedFor: null
    Connections {
        target: Media
        function onPlayerChanged(): void {
            if (proc.running && Media.player && Media.player !== root.startedFor) {
                root.restartPending = true;
                proc.running = false;
            }
        }
    }

    // Wire the player (or, failing that, the speaker output) into cava.
    // Runs a moment after cava starts (its node must exist) and when the
    // player's streams change; pw-link ignores links that already exist.
    Timer {
        id: linkTimer
        interval: 250
        onTriggered: {
            const sink = Pipewire.defaultAudioSink?.name ?? "";
            linker.command = ["sh", "-c", root.linkScript, "sh", sink].concat(root.playerStreams);
            linker.running = true;
        }
    }
    readonly property string linkScript: '
sink=$1; shift
link() { pw-link "$1" "altair-cava:input_$2" 2>/dev/null; }
found=0
if [ $# -gt 0 ]; then
    pw-link -o -I > "${XDG_RUNTIME_DIR:-/tmp}/altair-cava-ports" 2>/dev/null
    while read -r id name; do
        node=${name%%:*}; port=${name#*:}
        for n in "$@"; do
            [ "$node" = "$n" ] || continue
            case $port in *_FL|*_MONO|*_0|*_AUX0) link "$id" FL; found=1;; esac
            case $port in *_FR|*_MONO|*_1|*_AUX1) link "$id" FR; found=1;; esac
        done
    done < "${XDG_RUNTIME_DIR:-/tmp}/altair-cava-ports"
    rm -f "${XDG_RUNTIME_DIR:-/tmp}/altair-cava-ports"
fi
if [ $found = 0 ] && [ -n "$sink" ]; then
    link "$sink:monitor_FL" FL; link "$sink:monitor_FR" FR
fi
'
    Process {
        id: linker
    }

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
            // cava 1.0's fixed sensitivity is on a much larger scale than its
            // docs suggest: measured with Spotify at full volume, autosens
            // settles around 30000–40000 and 60–1000 leaves the bars flat.
            "sensitivity = " + ({ low: 6000, medium: 15000, high: 35000 }[sensitivity] ?? 100),
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
        // Own node name, not connected by the session manager (see top).
        environment: ({ PIPEWIRE_PROPS: "{ node.name = altair-cava node.autoconnect = false }" })
        onRunningChanged: if (running) { root.startedFor = Media.player; linkTimer.restart(); }
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
