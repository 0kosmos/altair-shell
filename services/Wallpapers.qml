// SPDX-License-Identifier: GPL-3.0-or-later
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.core
import qs.theme

// Wallpaper state: the current wallpaper (image or video), hover previews from
// the picker, cached thumbnails/still frames, and the live-wallpaper process.
//
// Images are drawn by wallpaper/Wallpaper.qml. Videos are played by a separate
// process (video/shell.qml), started only while a video wallpaper is set: video
// decoding costs ~250–350 MB, which should not live in the main shell. Under the
// video, Wallpaper.qml shows a full-size still frame of it, so starting,
// pausing and hover previews look seamless.
//
// Thumbnails (384x216) and still frames (screen size) are made in a separate
// process, one at a time: vipsthumbnail for images, ffmpeg for videos. They are
// cached in $XDG_CACHE_HOME/altair/thumbs. If a tool is missing or fails,
// images fall back to Qt decoding the original (not cached).
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")

    // ---- Settings ---------------------------------------------------------------
    // Absolute path of the current wallpaper, or "" for none.
    readonly property string current: Config.ready ? expand(Config.wallpaper.path) : ""
    readonly property string folder: expand(Config.wallpaper.folder || "~/Pictures/Wallpapers")
    readonly property string fill: Config.wallpaper.fill === "fit" ? "fit" : "crop"
    readonly property bool liveEnabled: Config.wallpaper.live.enabled && !Theme.lowPower
    readonly property real speed: Math.max(0.25, Math.min(2, Config.wallpaper.live.speed || 1))
    readonly property string pauseWhen: Config.wallpaper.live.pauseWhen

    readonly property list<string> imageFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp", "*.avif", "*.jxl", "*.bmp"]
    readonly property list<string> videoFilters: ["*.mp4", "*.webm", "*.mkv", "*.mov", "*.m4v"]

    function set(path: string): void {
        preview = "";
        Config.wallpaper.path = path;
    }

    function isVideo(path: string): bool {
        return /\.(mp4|webm|mkv|mov|m4v)$/i.test(path);
    }

    function expand(p: string): string {
        return p.startsWith("~/") ? home + p.slice(1) : p;
    }

    // /home/me/x -> ~/x
    function pretty(p: string): string {
        return p.startsWith(home + "/") ? "~" + p.slice(home.length) : p;
    }

    // file:// URL with each path segment escaped (spaces, #, % in names).
    function url(path: string): string {
        return path ? "file://" + path.split("/").map(encodeURIComponent).join("/") : "";
    }

    // ---- Hover preview ----------------------------------------------------------
    // Set by the picker while hovering/moving; drawn above the real wallpaper.
    property string preview: ""

    // What the still-image layer shows for a wallpaper: the image itself, or the
    // still frame of a video ("" while that frame is still being made).
    function stillFor(path: string): string {
        if (!isVideo(path))
            return path;
        void stillVersion;   // re-evaluate when a still frame finishes
        if (stillsDone[path])
            return stillPath(path);
        // Deferred: this runs inside bindings, which must not change state.
        Qt.callLater(root.requestStill, path);
        return "";
    }

    // ---- Thumbnails and still frames ---------------------------------------------
    readonly property string thumbDir: (Quickshell.env("XDG_CACHE_HOME") || home + "/.cache") + "/altair/thumbs"

    function thumbFor(path: string, modified: real, size: real): string {
        return thumbDir + "/" + Qt.md5(path + "|" + modified + "|" + size) + ".jpg";
    }
    function stillPath(path: string): string {
        return thumbDir + "/" + Qt.md5(path) + "-still.jpg";
    }

    property bool vipsAvailable: true
    property var failed: ({})        // sources a tool failed on
    property var stillsDone: ({})    // video path -> true once its still frame exists
    property int stillVersion: 0
    property var queue: []           // [{ kind: "thumb" | "still", src, out }]

    signal thumbReady(string thumb)
    signal thumbFailed(string src)

    function request(src: string, thumb: string): void {
        enqueue({ kind: "thumb", src, out: thumb });
    }

    function requestStill(path: string): void {
        enqueue({ kind: "still", src: path, out: stillPath(path) });
    }

    function enqueue(job): void {
        if (queue.some(j => j.out === job.out) || worker.job?.out === job.out)
            return;
        // Still frames first: they are what's on screen.
        queue = job.kind === "still" ? [job, ...queue] : [...queue, job];
        pump();
    }

    function pump(): void {
        if (worker.running || queue.length === 0)
            return;
        worker.job = queue[0];
        queue = queue.slice(1);
        worker.running = true;
    }

    // Commands get file names as $1/$2 (never pasted into the script).
    // Still frames: 1 s in (skips black intros), scaled to cover the screen.
    // `test -s` keeps an existing still frame instead of re-making it.
    readonly property string screenSize: {
        const s = Quickshell.screens[0];
        return s ? `${s.width}:${s.height}` : "1920:1080";
    }

    Process {
        id: worker
        property var job: null
        command: {
            const j = job;
            if (!j)
                return ["true"];
            const mk = "mkdir -p \"$(dirname \"$2\")\" && ";
            if (j.kind === "still")
                return ["sh", "-c", mk + "test -s \"$2\" || exec ffmpeg -v error -y -ss 1 -i \"$1\" -frames:v 1 -vf \"scale=" + root.screenSize
                    + ":force_original_aspect_ratio=increase,crop=" + root.screenSize + "\" -q:v 3 \"$2\"", "sh", j.src, j.out];
            if (root.isVideo(j.src))
                return ["sh", "-c", mk + "exec ffmpeg -v error -y -ss 1 -i \"$1\" -frames:v 1 -vf \"scale=384:216:force_original_aspect_ratio=increase,crop=384:216\" -q:v 4 \"$2\"",
                    "sh", j.src, j.out];
            return ["sh", "-c", mk + "exec vipsthumbnail \"$1\" -s 384x216 -m centre --path=\"$2[Q=85,strip]\" 2>/dev/null", "sh", j.src, j.out];
        }
        onExited: code => {
            const j = worker.job;
            worker.job = null;
            if (j.kind === "still") {
                if (code === 0) {
                    const d = Object.assign({}, root.stillsDone);
                    d[j.src] = true;
                    root.stillsDone = d;
                    root.stillVersion++;
                } else {
                    console.warn("altair: could not make a still frame of " + j.src + " (is ffmpeg installed?)");
                }
            } else if (code === 0) {
                root.thumbReady(j.out);
            } else {
                if (code === 127 && !root.isVideo(j.src))
                    root.vipsAvailable = false;
                const f = Object.assign({}, root.failed);
                f[j.src] = true;
                root.failed = f;
                root.thumbFailed(j.src);
            }
            root.pump();
        }
    }

    // ---- Live wallpaper process ----------------------------------------------------
    readonly property bool liveWanted: liveEnabled && isVideo(current)

    // Pause while windows are on screen (per setting). Paused = decoder idle,
    // ~0 % CPU; the frame stays on screen.
    readonly property bool windowsVisible: Hyprland.monitors.values.some(m => (m.activeWorkspace?.toplevels.values.length ?? 0) > 0)
    readonly property bool fullscreenVisible: Hyprland.monitors.values.some(m => m.activeWorkspace?.hasFullscreen ?? false)
    readonly property bool livePaused: pauseWhen === "window" ? windowsVisible
        : pauseWhen === "fullscreen" ? fullscreenVisible : false

    onLiveWantedChanged: restartLive()
    onCurrentChanged: restartLive()
    onLivePausedChanged: sendLive(livePaused ? ["pause"] : ["play"])
    onSpeedChanged: sendLive(["setSpeed", String(speed)])
    onFillChanged: sendLive(["setFill", fill])

    function restartLive(): void {
        live.running = false;
        if (liveWanted)
            Qt.callLater(() => live.running = root.liveWanted);
    }

    // Commands to the running video process over Quickshell IPC.
    function sendLive(args: list<string>): void {
        if (live.running && live.processId)
            Quickshell.execDetached(["qs", "ipc", "--pid", String(live.processId), "call", "video", ...args]);
    }

    Process {
        id: live
        command: ["qs", "-p", Quickshell.shellDir + "/video"]
        environment: ({
            ALTAIR_VIDEO: root.current,
            ALTAIR_VIDEO_SPEED: String(root.speed),
            ALTAIR_VIDEO_FILL: root.fill,
            ALTAIR_VIDEO_PAUSED: root.livePaused ? "1" : "0",
            ALTAIR_PARENT_PID: String(Quickshell.processId)
        })
        onExited: code => {
            // 15 = SIGTERM: we stopped it ourselves (switch, restart, reload).
            if (root.liveWanted && code !== 0 && code !== 15)
                console.warn("altair: live wallpaper player exited with code " + code + "; showing the still frame.");
        }
    }

    Component.onCompleted: restartLive()
}
