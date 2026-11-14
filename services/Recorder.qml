// SPDX-License-Identifier: GPL-3.0-or-later
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.core

// Screen recording with gpu-screen-recorder (optional dependency): the
// focused monitor at 60 fps, encoded on the GPU (NVENC / VA-API), so it costs
// almost no CPU. Files go to $XDG_VIDEOS_DIR/Recordings. Toggle from the bar
// button, or `qs -c altair ipc call recorder toggle`.
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
    readonly property string folder: (Quickshell.env("XDG_VIDEOS_DIR") || videosDir || (Quickshell.env("HOME") + "/Videos")) + "/Recordings"
    property string videosDir: ""

    Component.onCompleted: check.running = true

    // Is it installed, and where is the user's Videos folder?
    Process {
        id: check
        command: ["sh", "-c", "command -v gpu-screen-recorder >/dev/null && echo yes || echo no; xdg-user-dir VIDEOS 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const l = this.text.trim().split("\n");
                root.available = l[0] === "yes";
                if (l[1] && l[1] !== Quickshell.env("HOME"))
                    root.videosDir = l[1];
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
        if (recording)
            return;
        if (!available) {
            notify("Screen recorder not installed", "Install it with: sudo pacman -S gpu-screen-recorder");
            recheck();
            return;
        }
        monitor = Hyprland.focusedMonitor?.name ?? "";
        const stamp = Qt.formatDateTime(new Date(), "yyyy-MM-dd_hh-mm-ss");
        file = folder + "/Recording_" + stamp + ".mp4";
        const args = ["gpu-screen-recorder", "-w", monitor || "screen", "-f", "60", "-c", "mp4", "-q", "high", "-o", file];
        if (audio === "system")
            args.push("-a", "default_output");
        else if (audio === "both")
            args.push("-a", "default_output|default_input");
        // The folder must exist first.
        proc.command = ["sh", "-c", 'mkdir -p "$1" && shift && exec "$@"', "sh", folder].concat(args);
        startedAt = new Date();
        proc.running = true;
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
            if (code === 0 || code === 130 || code === 2)
                root.notify("Recording saved", root.file.replace(Quickshell.env("HOME"), "~"), true);
            else
                root.notify("Recording failed", (errors.text.trim().split("\n").pop() || ("exit code " + code)).slice(0, 200));
        }
    }

    // Through the notification daemon (Altair's own), with "Open folder".
    function notify(title: string, body: string, withAction: bool): void {
        const args = ["notify-send", "-a", "Altair", "-i", "media-record", title, body];
        if (withAction) {
            opener.command = ["sh", "-c", 'a=$(notify-send -a Altair -i media-record -A open="Open folder" "$1" "$2") && [ "$a" = open ] && xdg-open "$3"', "sh", title, body, folder];
            opener.running = true;
        } else {
            Quickshell.execDetached(args);
        }
    }
    Process {
        id: opener
    }
}
