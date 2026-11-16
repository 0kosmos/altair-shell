// SPDX-License-Identifier: GPL-3.0-or-later
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.core

// Clipboard history (opt-in, Settings > Clipboard) on top of `cliphist`.
// While on, one small helper keeps `wl-paste --watch cliphist store` running
// for text and for images (0 CPU between copies). Copies a password manager
// marks as secret are never stored: wl-paste sets CLIPBOARD_STATE=sensitive
// for them and cliphist skips those.
// The list is read when the panel opens; image thumbnails are decoded then,
// once, into ~/.cache/altair/clipboard/.
Singleton {
    id: root

    readonly property bool enabled: Config.ready && Config.clipboard.enabled
    readonly property int maxItems: Config.ready ? Math.max(20, Config.clipboard.maxItems) : 500
    readonly property bool autoPaste: Config.ready && Config.clipboard.autoPaste
    property bool available: false      // cliphist installed
    property bool checked: false

    // [{ id, line, text, image, info }] newest first.
    property var entries: []
    property bool loading: false

    readonly property string cacheDir: (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/altair/clipboard"
    function thumb(id: string): string {
        return cacheDir + "/" + id + ".png";
    }
    property var thumbsDone: ({})
    property int thumbVersion: 0

    Process {
        running: true
        command: ["sh", "-c", "command -v cliphist && command -v wl-paste && command -v wl-copy"]
        onExited: code => {
            root.available = code === 0;
            root.checked = true;
        }
    }

    // ---- Recording copies --------------------------------------------------------------
    // `cat` watches our stdin: when the shell exits (or this is switched
    // off), both watchers are stopped with it.
    Process {
        running: root.enabled && root.available
        stdinEnabled: true
        command: ["sh", "-c",
            'wl-paste --type text --watch cliphist -max-items "$1" store & a=$!; '
            + 'wl-paste --type image --watch cliphist -max-items "$1" store & b=$!; '
            + 'cat > /dev/null; kill $a $b', "sh", String(root.maxItems)]
    }

    // ---- Reading the list ----------------------------------------------------------------
    function refresh(): void {
        if (!available || listProc.running)
            return;
        loading = true;
        listProc.running = true;
    }
    Process {
        id: listProc
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = [];
                for (const line of text.split("\n")) {
                    const tab = line.indexOf("\t");
                    if (tab <= 0)
                        continue;
                    const id = line.slice(0, tab);
                    const preview = line.slice(tab + 1);
                    // "[[ binary data 340 KiB png 1920x1080 ]]"
                    const m = preview.match(/^\[\[ binary data (.+?) (png|jpeg|jpg|gif|webp|bmp) (\d+x\d+) \]\]$/);
                    out.push(m
                        ? { id: id, line: line, text: "", image: true, info: m[2].toUpperCase() + " · " + m[3].replace("x", " × ") + " · " + m[1] }
                        : { id: id, line: line, text: preview, image: false, info: "" });
                }
                root.entries = out;
                root.loading = false;
                root.queueThumbs();
            }
        }
    }

    // Thumbnails for image entries, one `cliphist decode` at a time.
    property var thumbQueue: []
    function queueThumbs(): void {
        const q = entries.filter(e => e.image && !thumbsDone[e.id]).map(e => e.id);
        thumbQueue = q;
        nextThumb();
    }
    function nextThumb(): void {
        if (thumbProc.running || thumbQueue.length === 0)
            return;
        const id = thumbQueue[0];
        thumbQueue = thumbQueue.slice(1);
        thumbProc.id = id;
        // Reuse a file from an earlier opening.
        thumbProc.command = ["sh", "-c", '[ -s "$2" ] || { mkdir -p "$3" && cliphist decode "$1" > "$2.tmp" && mv "$2.tmp" "$2"; }',
            "sh", id, thumb(id), cacheDir];
        thumbProc.running = true;
    }
    Process {
        id: thumbProc
        property string id
        onExited: code => {
            if (code === 0) {
                const d = root.thumbsDone;
                d[id] = true;
                root.thumbsDone = d;
                root.thumbVersion++;
            }
            root.nextThumb();
        }
    }

    // ---- Using an entry ---------------------------------------------------------------
    // Terminals paste with Ctrl+Shift+V (matched by window class).
    readonly property var terminalHints: ["kitty", "foot", "alacritty", "wezterm", "konsole", "terminal", "term",
        "console", "ghostty", "tilix", "terminator", "blackbox", "rio", "st-256color"]
    function isTerminal(cls: string): bool {
        cls = cls.toLowerCase();
        return cls === "st" || terminalHints.some(h => cls.indexOf(h) !== -1);
    }

    // Copy the entry to the clipboard again; with autoPaste also paste it
    // into the window that had focus before the panel opened.
    function use(entry: var, paste: bool): void {
        if (!entry)
            return;
        const cls = Hyprland.activeToplevel?.lastIpcObject?.class ?? Hyprland.activeToplevel?.wayland?.appId ?? "";
        const mods = isTerminal(cls) ? "CTRL SHIFT" : "CTRL";
        // After the panel has closed and given keyboard focus back.
        const pasteCmd = paste
            ? `sleep 0.18; hyprctl dispatch 'hl.dsp.send_shortcut({ mods = "${mods}", key = "V" })' > /dev/null`
            : ":";
        Quickshell.execDetached(["sh", "-c", 'cliphist decode "$1" | wl-copy && { ' + pasteCmd + '; }', "sh", entry.id]);
    }

    function remove(entry: var): void {
        if (!entry)
            return;
        entries = entries.filter(e => e.id !== entry.id);
        Quickshell.execDetached(["sh", "-c", 'printf "%s\\n" "$1" | cliphist delete; rm -f "$2"', "sh", entry.line, thumb(entry.id)]);
    }

    function wipe(): void {
        entries = [];
        thumbsDone = ({});
        Quickshell.execDetached(["sh", "-c", 'cliphist wipe; rm -f "$1"/*.png "$1"/*.tmp', "sh", cacheDir]);
    }
}
