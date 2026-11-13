// SPDX-License-Identifier: GPL-3.0-or-later
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.core
import qs.theme

// Small helpers around Hyprland IPC.
//
// Hyprland.dispatch() sends its string to Hyprland's `dispatch` request. With a
// Lua config (Hyprland 0.55+) that string is evaluated as `hl.dispatch(<string>)`,
// so it must be a Lua dispatcher expression; older Hyprland wants hyprlang syntax.
Singleton {
    id: root

    // ---- Hyprland look: blur strength and window borders -----------------------
    // Hyprland has ONE blur setting (decoration.blur size/passes) and one set of
    // border options for all windows and layer surfaces, so these settings are
    // global. They are applied at runtime with `hyprctl eval`; hyprland.lua is
    // never edited.
    //
    // To switch back ("Hyprland's own setting") without a config reload (a
    // reload re-applies all window rules, which makes open windows jump), we
    // remember the user's original values:
    //   - read from Hyprland before we change anything, and after every config
    //     reload (the user may have edited hyprland.lua);
    //   - stored per Hyprland session in $XDG_STATE_HOME/altair/hyprland-original.json,
    //     so restarting the shell doesn't mistake our own overrides for theirs.

    // Blur strength 1–10, or -1 = keep Hyprland's own.
    readonly property int blurStrength: Config.ready ? Config.effects.blurStrength : -1

    // "accent": focused window in the accent colour, others a faint grey.
    // "none": invisible borders. "hyprland": as configured in hyprland.lua.
    //
    // NOTE: "none" makes the borders fully transparent rather than 0 px wide.
    // Changing border_size makes Hyprland resize every window (they visibly
    // wobble with spring animations); colours can change without any layout
    // change. The cost is an invisible 2 px edge around windows.
    readonly property string borderMode: {
        const v = Config.ready ? Config.appearance.windowBorders : "hyprland";
        return v === true || v === "accent" ? "accent" : v === "none" ? "none" : "hyprland";
    }
    readonly property string accentBorders:
        `active_border = "${rgba(Theme.accent, 0.93)}", inactive_border = "${rgba(Theme.fg, 0.18)}"`

    // { borderSize, active, inactive, blurSize, blurPasses } — Lua values.
    property var original: null
    readonly property string session: Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") ?? ""

    onBlurStrengthChanged: applyBlur()
    onBorderModeChanged: applyBorders()
    onAccentBordersChanged: if (borderMode === "accent") applyBorders()

    function applyBlur(): void {
        if (!original || !Config.ready)
            return;
        const s = Math.min(10, blurStrength);
        const size = s < 1 ? original.blurSize : 2 + s;                          // 3 … 12
        const passes = s < 1 ? original.blurPasses : s <= 3 ? 1 : s <= 7 ? 2 : 3; // more = smoother, costlier
        hyprEval(`hl.config({ decoration = { blur = { size = ${size}, passes = ${passes} } } })`);
    }

    // Border size we last sent; only re-sent when it differs (see NOTE above).
    property int appliedBorderSize: -1

    function applyBorders(): void {
        if (!original || !Config.ready)
            return;
        const colors = borderMode === "accent" ? accentBorders
            : borderMode === "none" ? `active_border = "rgba(00000000)", inactive_border = "rgba(00000000)"`
            : `active_border = ${original.active}, inactive_border = ${original.inactive}`;
        const size = appliedBorderSize !== original.borderSize ? `border_size = ${original.borderSize}, ` : "";
        appliedBorderSize = original.borderSize;
        hyprEval(`hl.config({ general = { ${size}col = { ${colors} } } })`);
    }

    function hyprEval(lua: string): void {
        Quickshell.execDetached(["hyprctl", "eval", lua]);
    }

    // Hyprland colour syntax: rgba(RRGGBBAA).
    function rgba(c: color, alpha: real): string {
        const h = v => Math.round(v * 255).toString(16).padStart(2, "0");
        return `rgba(${h(c.r)}${h(c.g)}${h(c.b)}${h(alpha)})`;
    }

    // "gradient data: ee33ccff ee00ff99 45deg" (AARRGGBB) -> a Lua value.
    function gradientToLua(line: string): string {
        const parts = line.replace(/^.*?:\s*/, "").trim().split(/\s+/);
        const angle = parseInt(parts.pop()) || 0;
        const cols = parts.map(c => `"rgba(${c.slice(2)}${c.slice(0, 2)})"`);
        return cols.length === 1 && angle === 0 ? cols[0] : `{ colors = { ${cols.join(", ")} }, angle = ${angle} }`;
    }

    function readOriginal(): void {
        reader.running = true;
    }

    Process {
        id: reader
        command: ["sh", "-c", "for o in general:border_size general:col.active_border general:col.inactive_border decoration:blur:size decoration:blur:passes; do hyprctl getoption \"$o\" | head -n1; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                const l = this.text.trim().split("\n");
                if (l.length < 5) {
                    console.warn("altair: could not read Hyprland options: " + this.text);
                    return;
                }
                const int = s => parseInt(s.replace(/^.*?:\s*/, ""));
                root.original = {
                    borderSize: int(l[0]),
                    active: root.gradientToLua(l[1]),
                    inactive: root.gradientToLua(l[2]),
                    blurSize: int(l[3]),
                    blurPasses: int(l[4])
                };
                store.session = root.session;
                store.values = root.original;
                root.applyBlur();
                root.applyBorders();
            }
        }
    }

    FileView {
        id: storeFile
        path: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/altair/hyprland-original.json"
        printErrors: false
        onAdapterUpdated: writeAdapter()
        // Same Hyprland session as last time: our overrides may be active, so
        // trust the stored originals instead of reading Hyprland.
        onLoaded: {
            if (store.session === root.session && store.values && store.values.blurSize !== undefined) {
                root.original = store.values;
                root.applyBlur();
                root.applyBorders();
            } else {
                root.readOriginal();
            }
        }
        onLoadFailed: root.readOriginal()

        JsonAdapter {
            id: store
            property string session: ""
            property var values: ({})
        }
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            // The config was re-read: Hyprland now has the user's values again.
            if (event.name === "configreloaded") {
                root.appliedBorderSize = -1;
                root.readOriginal();
            }
        }
    }

    // ---- Dispatch -------------------------------------------------------------
    function dispatch(lua: string, legacy: string): void {
        Hyprland.dispatch(Hyprland.usingLua ? lua : legacy);
    }

    function focusWorkspace(id: int): void {
        dispatch(`hl.dsp.focus({ workspace = ${id} })`, `workspace ${id}`);
    }

    // Move to the next/previous existing workspace on the current monitor.
    function cycleWorkspace(delta: int): void {
        const target = delta > 0 ? "e+1" : "e-1";
        dispatch(`hl.dsp.focus({ workspace = "${target}" })`, `workspace ${target}`);
    }

    // Run a program through Hyprland, like a keybind would. Compared with
    // starting it from Quickshell, the app gets Hyprland's environment (not
    // ours, e.g. no EGL override), Hyprland's exec rules apply, and it isn't
    // tied to the shell process in any way.
    // argv: list of arguments (no shell parsing). cwd: optional directory.
    function exec(argv: list<string>, cwd: string): void {
        let cmd = argv.map(shellQuote).join(" ");
        if (cwd)
            cmd = "cd " + shellQuote(cwd) + " && " + cmd;
        dispatch(`hl.dsp.exec_cmd(${luaString(cmd)})`, `exec ${cmd}`);
    }

    // 'it'\''s' — safe single-quoting for /bin/sh.
    function shellQuote(s: string): string {
        return "'" + String(s).replace(/'/g, "'\\''") + "'";
    }

    // A double-quoted Lua string literal.
    function luaString(s: string): string {
        return '"' + s.replace(/\\/g, "\\\\").replace(/"/g, '\\"').replace(/\n/g, "\\n") + '"';
    }
}
