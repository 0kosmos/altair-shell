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
}
