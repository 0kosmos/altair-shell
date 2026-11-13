// SPDX-License-Identifier: GPL-3.0-or-later
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland

// Small helpers around Hyprland IPC.
//
// Hyprland.dispatch() sends its string to Hyprland's `dispatch` request. With a
// Lua config (Hyprland 0.55+) that string is evaluated as `hl.dispatch(<string>)`,
// so it must be a Lua dispatcher expression; older Hyprland wants hyprlang syntax.
Singleton {
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
