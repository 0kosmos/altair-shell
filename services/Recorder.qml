// SPDX-License-Identifier: GPL-3.0-or-later
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.core

// Screen recording with gpu-screen-recorder (optional dependency): the
// focused monitor or a dragged region, encoded on the GPU (NVENC / VA-API),
// so it costs almost no CPU. Files go to $XDG_VIDEOS_DIR/Recordings.
// Left-click the bar button to start/stop, right-click for the recorder menu
// (recorder/RecorderPanel.qml), or `qs -c altair ipc call recorder toggle`.
Singleton {
    id: root

    property bool available: false
    property bool checked: false
    readonly property bool recording: proc.running
    property date startedAt: new Date()
    property string file: ""
    property string monitor: ""

    // "none" | "system" | "both" (system sound + microphone)
    readonly property string audio: Config.ready ? Config.recorder.audio : "system"
    readonly property string target: Config.ready && Config.recorder.target === "region" ? "region" : "screen"
    readonly property int fps: Config.ready ? Math.max(15, Math.min(240, Config.recorder.fps)) : 60
    readonly property string quality: Config.ready && ["medium", "high", "very_high", "ultra"].indexOf(Config.recorder.quality) !== -1 ? Config.recorder.quality : "high"
    // Only codecs the GPU can encode (from `gpu-screen-recorder --info`).
    property var codecs: ["h264"]
    readonly property string codec: Config.ready && codecs.indexOf(Config.recorder.codec) !== -1 ? Config.recorder.codec : "h264"
    readonly property bool cursor: !Config.ready || Config.recorder.cursor
    property bool hasSlurp: false
    readonly property string folder: (Quickshell.env("XDG_VIDEOS_DIR") || videosDir || (Quickshell.env("HOME") + "/Videos")) + "/Recordings"
    property string videosDir: ""

    Component.onCompleted: check.running = true

    // Is it installed, and where is the user's Videos folder?
    Process {
        id: check
        command: ["sh", "-c", "command -v gpu-screen-recorder >/dev/null && echo yes || echo no; xdg-user-dir VIDEOS 2>/dev/null || echo; "
            + "command -v slurp >/dev/null && echo slurp || echo; "
            + "gpu-screen-recorder --info 2>/dev/null | sed -n '/^section=video_codecs/,/^section=/p' | grep -xE 'h264|hevc|av1' | tr '\\n' ' '"]
        stdout: StdioCollector {
            onStreamFinished: {
                const l = this.text.split("\n");
                root.available = l[0] === "yes";
                if (l[1] && l[1] !== Quickshell.env("HOME"))
                    root.videosDir = l[1];
                root.hasSlurp = l[2] === "slurp";
                const c = (l[3] ?? "").trim().split(/\s+/).filter(x => x);
                if (c.length > 0)
                    root.codecs = c;
                root.checked = true;
            }
        }
    }
    function recheck(): void {
        if (!check.running)
            check.running = true;
    }

    function toggle(): void {
        if (recording)
            stop();
        else
            start();
    }

    function start(): void {
        if (recording || selecting.running)
            return;
        if (!available) {
            notify("Screen recorder not installed", "Install it with: sudo pacman -S gpu-screen-recorder");
            recheck();
            return;
        }
        if (target === "region" && hasSlurp) {
            // Drag a rectangle first; Esc in slurp cancels.
            selecting.running = true;
            return;
        }
        launch(Hyprland.focusedMonitor?.name || "screen", "");
    }

    Process {
        id: selecting
        // < /dev/null: with a pipe as stdin, slurp waits to read preset
        // boxes from it and never shows the selection.
        command: ["sh", "-c", 'exec slurp -f "%wx%h+%x+%y" -d < /dev/null']
        stdout: StdioCollector {
            id: picked
        }
        onExited: code => {
            const geo = picked.text.trim();
            if (code === 0 && /^\d+x\d+\+-?\d+\+-?\d+$/.test(geo))
                root.launch("region", geo);
        }
    }

    function launch(what: string, region: string): void {
        monitor = what === "region" ? "" : what;
        const stamp = Qt.formatDateTime(new Date(), "yyyy-MM-dd_hh-mm-ss");
        file = folder + "/Recording_" + stamp + ".mp4";
        const args = ["gpu-screen-recorder", "-w", what];
        if (region)
            args.push("-region", region);
        args.push("-f", String(fps), "-c", "mp4", "-k", codec, "-q", quality, "-cursor", cursor ? "yes" : "no", "-o", file);
        if (audio === "system")
            args.push("-a", "default_output");
        else if (audio === "both")
            args.push("-a", "default_output|default_input");
        // The folder must exist first.
        proc.command = ["sh", "-c", 'mkdir -p "$1" && shift && exec "$@"', "sh", folder].concat(args);
        startedAt = new Date();
        proc.running = true;
    }

    // Recent clips in the folder (for the menu), newest first: [{ path, name, size, time }].
    property var recent: []
    function loadRecent(): void {
        if (!recentProc.running)
            recentProc.running = true;
    }
    Process {
        id: recentProc
        command: ["sh", "-c", 'cd "$1" 2>/dev/null && ls -t -- *.mp4 *.mkv *.webm 2>/dev/null | head -4 | while IFS= read -r f; do printf "%s\t%s\t%s\n" "$f" "$(stat -c %s -- "$f")" "$(stat -c %Y -- "$f")"; done', "sh", root.folder]
        stdout: StdioCollector {
            onStreamFinished: {
                root.recent = this.text.split("\n").filter(l => l).map(l => {
                    const p = l.split("\t");
                    return { path: root.folder + "/" + p[0], name: p[0], size: Number(p[1]), time: Number(p[2]) * 1000 };
                });
            }
        }
    }


    // SIGINT: gpu-screen-recorder finishes writing the file and exits.
    function stop(): void {
        if (recording)
            proc.signal(2);
    }

    Process {
        id: proc
        stderr: StdioCollector { id: errors }
        onExited: code => {
            // 0 = saved; 130/2 = stopped by our SIGINT (also saved).
            if (code === 0 || code === 130 || code === 2) {
                root.notify("Recording saved", root.file.replace(Quickshell.env("HOME"), "~"), true);
                root.loadRecent();
            }
            else
                root.notify("Recording failed", (errors.text.trim().split("\n").pop() || ("exit code " + code)).slice(0, 200));
        }
    }

    // Through the notification daemon (Altair's own). A saved clip gets
    // "Play" and "Show in folder" (the file manager, with the clip selected).
    function notify(title: string, body: string, withAction: bool): void {
        if (withAction) {
            opener.clip = file;
            opener.command = ["notify-send", "-a", "Altair", "-i", "media-record",
                "-A", "play=Play", "-A", "show=Show in folder", title, body];
            opener.running = true;
        } else {
            Quickshell.execDetached(["notify-send", "-a", "Altair", "-i", "media-record", title, body]);
        }
    }
    Process {
        id: opener
        property string clip
        stdout: StdioCollector {
            onStreamFinished: {
                const a = this.text.trim();
                if (a === "play")
                    Files.open(opener.clip);
                else if (a === "show")
                    Files.showItem(opener.clip);
            }
        }
    }
}
