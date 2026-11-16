// SPDX-License-Identifier: GPL-3.0-or-later
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import qs.core

// Music equalizer: 6 bands (60 Hz – 15 kHz, like Spotify's), presets, only
// for the music player's audio.
//
// How: while on (and not Flat), a small PipeWire filter process runs
// (`pipewire -c <config>`, libpipewire-module-filter-chain with biquad
// filters, no extra packages). It adds a virtual output "Altair Equalizer"
// that plays into the normal output, and the player's streams are moved into
// it (`pactl move-sink-input`); other audio is untouched. Gains change live
// (`pw-cli set-param`). Off/Flat: the process is stopped, and PipeWire moves
// the player back to the normal output by itself, even if the filter process
// dies or is killed. No PipeWire/WirePlumber config file is ever written.
Singleton {
    id: root

    readonly property var freqs: [60, 150, 400, 1000, 2400, 15000]
    readonly property var freqLabels: ["60", "150", "400", "1K", "2.4K", "15K"]
    readonly property int maxGain: 12

    // Gains in dB per band. Own curves, tuned by ear for typical music.
    readonly property var presets: [
        { id: "flat", name: "Flat", gains: [0, 0, 0, 0, 0, 0] },
        { id: "acoustic", name: "Acoustic", gains: [3, 2, 0.5, 1, 2, 2.5] },
        { id: "bass", name: "Bass Booster", gains: [6, 4, 1.5, 0, 0, 0] },
        { id: "bassless", name: "Bass Reducer", gains: [-6, -4, -1.5, 0, 0, 0] },
        { id: "classical", name: "Classical", gains: [3, 2, 0, 0, 1.5, 3] },
        { id: "dance", name: "Dance", gains: [4, 3, 0, 1, 2.5, 2] },
        { id: "electronic", name: "Electronic", gains: [4, 3, 0, -1, 2, 4] },
        { id: "hiphop", name: "Hip-Hop", gains: [5, 3.5, 0.5, 1, -0.5, 1.5] },
        { id: "jazz", name: "Jazz", gains: [3, 1.5, 1, -1, 1, 2.5] },
        { id: "loudness", name: "Loudness", gains: [5, 2, 0, -1, 1.5, 4] },
        { id: "pop", name: "Pop", gains: [-1, 1, 3, 3, 1, -1] },
        { id: "rnb", name: "R&B", gains: [3, 6, 2, -1, 2, 2.5] },
        { id: "rock", name: "Rock", gains: [4, 2.5, -1, 0, 2, 3.5] },
        { id: "small", name: "Small Speakers", gains: [5, 3.5, 1.5, 0.5, -1, -2] },
        { id: "treble", name: "Treble Booster", gains: [0, 0, 0, 1.5, 4, 6] },
        { id: "vocal", name: "Vocal Booster", gains: [-2, -1, 2, 4, 3, 1] },
        { id: "custom", name: "Custom", gains: null },
    ]

    // ---- Settings (config.json "equalizer") ----------------------------------------
    readonly property bool enabled: Config.ready && Config.equalizer.enabled
    readonly property string preset: Config.ready && presets.some(p => p.id === Config.equalizer.preset) ? Config.equalizer.preset : "flat"
    readonly property var custom: {
        const c = Config.ready ? Config.equalizer.custom : null;
        const l = c && c.length !== undefined ? Array.from(c).map(Number) : [];
        return freqs.map((f, i) => Math.max(-maxGain, Math.min(maxGain, isFinite(l[i]) ? l[i] : 0)));
    }
    readonly property var gains: preset === "custom" ? custom : presets.find(p => p.id === preset).gains
    readonly property string presetName: presets.find(p => p.id === preset)?.name ?? "Flat"

    function setEnabled(on: bool): void {
        Config.equalizer.enabled = on;
    }
    function setPreset(id: string): void {
        Config.equalizer.preset = id;
    }
    function stepPreset(delta: int): void {
        const i = presets.findIndex(p => p.id === preset);
        setPreset(presets[(i + delta + presets.length) % presets.length].id);
    }
    // Moving one band makes the current curve the Custom preset.
    function setBand(i: int, db: real): void {
        const g = gains.slice();
        g[i] = Math.round(Math.max(-maxGain, Math.min(maxGain, db)) * 2) / 2;   // 0.5 dB steps
        Config.equalizer.custom = g;
        Config.equalizer.preset = "custom";
    }

    // ---- The filter process ---------------------------------------------------------
    readonly property bool flat: gains.every(g => g === 0)
    // The filter runs whenever the equalizer is on, also on Flat: removing
    // the sink under a playing app (Spotify) makes it pause, and switching
    // presets used to pass through Flat.
    readonly property bool wanted: enabled
    readonly property string confPath: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/altair-eq.conf"
    readonly property string sinkName: "altair_eq_sink"
    // True once the filter's sink exists in PipeWire.
    readonly property bool ready: proc.running && (Pipewire.nodes?.values ?? []).some(n => n.name === sinkName)

    onWantedChanged: Qt.callLater(update)
    Component.onCompleted: cleanup.running = true   // a leftover from a previous run

    function update(): void {
        if (cleanup.running)
            return;   // update() runs again when the cleanup is done
        if (wanted && !proc.running) {
            conf.setText(config());
            proc.running = true;
        } else if (!wanted && proc.running && !unroute.running) {
            // Move the player back to the normal output first, then stop the
            // filter (a sink vanishing under it makes some players pause).
            unroute.running = true;
        }
    }

    Process {
        id: unroute
        command: ["sh", "-c", "s=$(pactl list short sinks | awk '$2==\"" + root.sinkName + "\"{print $1}'); "
            + "[ -n \"$s\" ] && pactl list short sink-inputs | awk -v s=\"$s\" '$3==s{print $1}' | "
            + "while read -r i; do pactl move-sink-input \"$i\" @DEFAULT_SINK@; done; true"]
        onExited: stopTimer.restart()
    }
    // Give PipeWire a moment to switch the stream before the sink goes.
    Timer {
        id: stopTimer
        interval: 250
        onTriggered: if (!root.wanted) proc.running = false
    }

    // Kill an equalizer left over from an earlier shell (e.g. after SIGKILL).
    Process {
        id: cleanup
        // (Matched at the end of the command line: it runs as
        // "/usr/bin/pipewire -c <path>"; dots escaped for the regex.)
        command: ["pkill", "-f", "pipewire -c " + root.confPath.replace(/\./g, "\\.") + "$"]
        onExited: root.update()
    }

    Process {
        id: proc
        command: ["pipewire", "-c", root.confPath]
        onExited: code => {
            if (root.wanted && code !== 0)
                console.warn("altair: equalizer process exited with code " + code);
        }
    }

    FileView {
        id: conf
        path: root.confPath
        blockWrites: true
        printErrors: false
    }

    // Preamp: lower everything by the biggest boost, so boosted bands can't clip.
    function preamp(g: var): real {
        return -Math.max(0, ...g);
    }

    function config(): string {
        const g = gains;
        const band = (i, label, q) => `{ type = builtin name = b${i + 1} label = ${label} control = { "Freq" = ${freqs[i].toFixed(1)} "Q" = ${q} "Gain" = ${g[i].toFixed(1)} } }`;
        const nodes = [`{ type = builtin name = pre label = bq_highshelf control = { "Freq" = 0.0 "Q" = 1.0 "Gain" = ${preamp(g).toFixed(1)} } }`];
        for (let i = 0; i < freqs.length; i++)
            nodes.push(band(i, i === 0 ? "bq_lowshelf" : i === freqs.length - 1 ? "bq_highshelf" : "bq_peaking", i === 0 || i === freqs.length - 1 ? "0.7" : "1.0"));
        const links = ["pre"].concat(freqs.map((f, i) => "b" + (i + 1)));
        const linkText = links.slice(1).map((n, i) => `{ output = "${links[i]}:Out" input = "${n}:In" }`).join(" ");
        return `# Generated by Altair (services/Equalizer.qml); rewritten on every start.
context.properties = { log.level = 0 }
context.spa-libs = {
  audio.convert.* = audioconvert/libspa-audioconvert
  support.* = support/libspa-support
}
context.modules = [
  { name = libpipewire-module-rt args = { } flags = [ ifexists nofail ] }
  { name = libpipewire-module-protocol-native }
  { name = libpipewire-module-client-node }
  { name = libpipewire-module-adapter }
  { name = libpipewire-module-filter-chain
    args = {
      node.description = "Altair Equalizer"
      media.name = "Altair Equalizer"
      filter.graph = {
        nodes = [ ${nodes.join("\n          ")} ]
        links = [ ${linkText} ]
      }
      audio.channels = 2
      audio.position = [ FL FR ]
      capture.props = { node.name = "${sinkName}" media.class = Audio/Sink }
      playback.props = { node.name = "altair_eq_output" node.passive = true }
    }
  }
]
`;
    }

    // ---- Live gains -------------------------------------------------------------------
    onGainsChanged: if (proc.running) applyTimer.restart()
    Timer {
        id: applyTimer
        interval: 60   // coalesce slider drags
        onTriggered: {
            if (!root.ready)
                return;
            if (setter.running) {
                setter.pending = true;   // apply the newest gains when it's done
                return;
            }
            const g = root.gains;
            const params = [`"pre:Gain" ${root.preamp(g).toFixed(1)}`].concat(g.map((v, i) => `"b${i + 1}:Gain" ${v.toFixed(1)}`));
            setter.command = ["pw-cli", "set-param", root.sinkName, "Props", `{ params = [ ${params.join(" ")} ] }`];
            setter.running = true;
        }
    }
    Process {
        id: setter
        property bool pending: false
        onExited: {
            if (pending) {
                pending = false;
                applyTimer.restart();
            }
        }
    }

    // ---- Routing: the music player's streams into the equalizer ----------------------
    // Re-checked when the filter becomes ready, the player changes, or audio
    // streams come and go (e.g. the player opens a new stream).
    readonly property string playerApp: Media.player ? [Media.player.identity, Media.player.desktopEntry].join("|") : ""
    readonly property int streamCount: (Pipewire.nodes?.values ?? []).filter(n => n.isStream).length
    onReadyChanged: if (ready) { applyTimer.restart(); routeTimer.restart(); }
    onPlayerAppChanged: if (ready) routeTimer.restart()
    onStreamCountChanged: if (ready) routeTimer.restart()

    Timer {
        id: routeTimer
        interval: 300
        onTriggered: if (root.ready && !lister.running) lister.running = true
    }

    Process {
        id: lister
        command: ["pactl", "-f", "json", "list", "sink-inputs"]
        stdout: StdioCollector {
            onStreamFinished: {
                let inputs = [];
                try {
                    inputs = JSON.parse(this.text);
                } catch (e) {
                    return;
                }
                const names = (Media.player ? [Media.player.identity, Media.player.desktopEntry, Media.appName] : [])
                    .filter(n => n).map(n => String(n).toLowerCase());
                if (names.length === 0)
                    return;
                const moves = inputs.filter(s => {
                    const p = s.properties ?? {};
                    const app = String(p["application.name"] ?? "").toLowerCase();
                    const bin = String(p["application.process.binary"] ?? "").toLowerCase();
                    return app && names.some(n => app === n || bin === n || app.includes(n) || n.includes(app));
                }).map(s => s.index);
                if (moves.length > 0) {
                    mover.command = ["sh", "-c", moves.map(i => `pactl move-sink-input ${i} ${root.sinkName}`).join("; ")];
                    mover.running = true;
                }
            }
        }
    }
    Process {
        id: mover
    }
}
