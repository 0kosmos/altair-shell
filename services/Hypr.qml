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
    //   - read ONLY right after a config reload, while all of our changes are
    //     held back, so what we read is guaranteed to be the user's own
    //     (reading at any other time could pick up our own overrides);
    //   - stored per Hyprland session in $XDG_STATE_HOME/altair/hyprland-original.json,
    //     so restarting the shell reuses them without another reload.
    // Without a stored record for this session (first start after login), we
    // trigger one `hyprctl reload config-only` to get that clean read.

    // Blur strength 1–10, or -1 = keep Hyprland's own.
    readonly property int blurStrength: Config.ready ? Config.effects.blurStrength : -1

    // "accent": focused window in the accent colour, others a faint grey.
    // "none": invisible borders. "hyprland": as configured in hyprland.lua.
    //
    // NOTE: "none" sets border_size 0. (Transparent 2 px borders were tried:
    // they avoid re-layout, but leave a see-through ring around every window.)
    // Changing border_size makes Hyprland re-lay-out all windows; with smooth
    // resizing on, that is a short glide using our calm curve.
    readonly property string borderMode: {
        const v = Config.ready ? Config.appearance.windowBorders : "hyprland";
        return v === true || v === "accent" ? "accent" : v === "none" ? "none" : "hyprland";
    }
    readonly property string accentBorders:
        `active_border = "${rgba(Theme.accent, 0.93)}", inactive_border = "${rgba(Theme.fg, 0.18)}"`

    // Resize windows by dragging their edges.
    readonly property bool resizeOnBorder: Config.ready ? Config.windows.resizeOnBorder : false
    onResizeOnBorderChanged: applyResize()

    function applyResize(): void {
        if (!original || !Config.ready || reading)
            return;
        hyprEval(`hl.config({ general = { resize_on_border = ${resizeOnBorder ? "true" : String(original.resizeOnBorder)} } })`);
    }

    // Smooth manual resizing/dragging: Hyprland animates windows following the
    // mouse (animate_manual_resizes / animate_mouse_windowdragging). Those use
    // the "windowsMove" animation, which in many configs is a bouncy spring, so
    // we also give it a calm, decelerating curve. Off = the user's own values.
    readonly property bool smoothResize: Config.ready ? Config.windows.smoothResize : false
    onSmoothResizeChanged: applySmooth()

    function applySmooth(): void {
        if (!original || !Config.ready || reading)
            return;
        if (smoothResize) {
            hyprEval('hl.curve("altairSmooth", { type = "bezier", points = { {0.16, 1}, {0.3, 1} } }) '
                + 'hl.animation({ leaf = "windowsMove", enabled = true, speed = 2.5, bezier = "altairSmooth" }) '
                + 'hl.config({ misc = { animate_manual_resizes = true, animate_mouse_windowdragging = true } })');
        } else {
            const m = original.moveAnim;
            hyprEval(`hl.animation({ leaf = "windowsMove", enabled = ${m.enabled}, speed = ${m.speed}, ${m.curve} }) `
                + `hl.config({ misc = { animate_manual_resizes = ${original.animResize}, animate_mouse_windowdragging = ${original.animDrag} } })`);
        }
    }

    // Default window opacity (focused / unfocused), 0.3–1, or -1 = Hyprland's
    // own. Per-app values are window rules, see services/WindowRules.qml.
    readonly property real activeOpacity: Config.ready ? Config.transparency.activeOpacity : -1
    readonly property real inactiveOpacity: Config.ready ? Config.transparency.inactiveOpacity : -1
    onActiveOpacityChanged: Qt.callLater(applyOpacity)
    onInactiveOpacityChanged: Qt.callLater(applyOpacity)

    function applyOpacity(): void {
        if (!original || !Config.ready || reading)
            return;
        const pick = (v, orig) => v > 0 ? Math.max(0.3, Math.min(1, v)) : orig;
        hyprEval(`hl.config({ decoration = { active_opacity = ${pick(activeOpacity, original.activeOpacity)}, `
            + `inactive_opacity = ${pick(inactiveOpacity, original.inactiveOpacity)} } })`);
    }

    // ---- Workspace switching animation --------------------------------------------
    // Style: "slide", "slidevert", "fade", "off", or "hyprland" (your own).
    // Applied to Hyprland's workspaces / workspacesIn / workspacesOut animations.
    readonly property string workspaceStyle: {
        const v = Config.ready ? Config.windows.workspaceAnim : "hyprland";
        return ["slide", "slidevert", "fade", "off"].indexOf(v) !== -1 ? v : "hyprland";
    }
    // Hyprland speed in tenths of a second.
    readonly property real workspaceSpeed: {
        const v = Config.ready ? Config.windows.workspaceSpeed : "calm";
        return v === "normal" ? 3.5 : v === "fast" ? 2.2 : 5;   // unknown -> calm
    }
    // The bezier we use, also mirrored by the bar's workspace pill.
    readonly property var workspaceCurve: [0.22, 1, 0.36, 1]
    // How long a workspace switch takes, in ms, for the bar to follow (0 = instant).
    readonly property int workspaceDuration: workspaceStyle === "off" ? 0
        : workspaceStyle === "hyprland" ? Math.round((original?.wsAnim?.[0]?.speed ?? 2.6) * 100)
        : Math.round(workspaceSpeed * 100)
    onWorkspaceStyleChanged: Qt.callLater(applyWorkspaces)
    onWorkspaceSpeedChanged: Qt.callLater(applyWorkspaces)

    function applyWorkspaces(): void {
        if (!original || !Config.ready || reading || !original.wsAnim)
            return;
        const leaves = ["workspaces", "workspacesIn", "workspacesOut"];
        let lua = "";
        if (workspaceStyle === "hyprland") {
            for (const a of original.wsAnim)
                lua += `hl.animation({ leaf = "${a.name}", enabled = ${a.enabled}, speed = ${a.speed}, ${a.curve}${a.style ? `, style = "${a.style}"` : ""} }) `;
        } else if (workspaceStyle === "off") {
            for (const n of leaves)
                lua += `hl.animation({ leaf = "${n}", enabled = false }) `;
        } else {
            const c = workspaceCurve;
            lua += `hl.curve("altairWorkspace", { type = "bezier", points = { {${c[0]}, ${c[1]}}, {${c[2]}, ${c[3]}} } }) `;
            // A fade with a slide feels busy; "slidefade" is not used on purpose.
            for (const n of leaves)
                lua += `hl.animation({ leaf = "${n}", enabled = true, speed = ${workspaceSpeed}, bezier = "altairWorkspace", style = "${workspaceStyle}" }) `;
        }
        hyprEval(lua);
    }

    // { borderSize, active, inactive, blurSize, blurPasses, resizeOnBorder,
    //   animResize, animDrag, activeOpacity, inactiveOpacity, moveAnim, wsAnim } — Lua values.
    property var original: null
    readonly property string session: Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") ?? ""

    onBlurStrengthChanged: applyBlur()
    onBorderModeChanged: applyBorders()
    onAccentBordersChanged: if (borderMode === "accent") applyBorders()

    function applyBlur(): void {
        if (!original || !Config.ready || reading)
            return;
        const s = Math.min(10, blurStrength);
        const size = s < 1 ? original.blurSize : 2 + s;                          // 3 … 12
        const passes = s < 1 ? original.blurPasses : s <= 3 ? 1 : s <= 7 ? 2 : 3; // more = smoother, costlier
        hyprEval(`hl.config({ decoration = { blur = { size = ${size}, passes = ${passes} } } })`);
    }

    // Border size we last sent; only re-sent when it differs (see NOTE above).
    property int appliedBorderSize: -1

    function applyBorders(): void {
        if (!original || !Config.ready || reading)
            return;
        const colors = borderMode === "accent" ? accentBorders
            : `active_border = ${original.active}, inactive_border = ${original.inactive}`;
        const wanted = borderMode === "none" ? 0 : original.borderSize;
        const size = appliedBorderSize !== wanted ? `border_size = ${wanted}, ` : "";
        appliedBorderSize = wanted;
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

    // True from "we need the user's values" until they have been read.
    property bool reading: false

    // What "windowsMove" does in the user's config, as Lua arguments: its own
    // settings if overridden, otherwise those of "windows" (which it inherits).
    function moveAnimFrom(json: string): var {
        try {
            const d = JSON.parse(json);
            const all = Array.isArray(d[0]) ? d[0] : d;
            const move = all.find(a => a.name === "windowsMove");
            const win = all.find(a => a.name === "windows");
            const a = move && move.overridden ? move : win;
            if ((a?.bezier ?? "").startsWith("altair"))
                return null;   // our own override, not the user's (see readerGuard)
            const curve = (a?.bezier ?? "").startsWith("spring:")
                ? `spring = "${a.bezier.slice(7)}"` : `bezier = "${a?.bezier || "default"}"`;
            return { enabled: a?.enabled !== false, speed: a?.speed || 5, curve };
        } catch (e) {
            console.warn("altair: could not read Hyprland animations: " + e);
            return { enabled: true, speed: 5, curve: 'bezier = "default"' };
        }
    }

    // The user's workspaces / workspacesIn / workspacesOut animations, as
    // [{ name, enabled, speed, curve, style }] (inherited values filled in).
    function wsAnimFrom(json: string): var {
        try {
            const d = JSON.parse(json);
            const all = Array.isArray(d[0]) ? d[0] : d;
            const get = n => all.find(a => a.name === n);
            const base = get("workspaces");
            return ["workspaces", "workspacesIn", "workspacesOut"].map(n => {
                const own = get(n);
                const a = own && own.overridden ? own : base && base.overridden ? base : (get("global") ?? own);
                if ((a?.bezier ?? "").startsWith("altair"))
                    throw "our own override";   // see readerGuard
                const curve = (a?.bezier ?? "").startsWith("spring:")
                    ? `spring = "${a.bezier.slice(7)}"` : `bezier = "${a?.bezier || "default"}"`;
                return { name: n, enabled: a?.enabled !== false, speed: a?.speed || 5, curve, style: (own?.overridden ? own.style : base?.style) || "" };
            });
        } catch (e) {
            console.warn("altair: could not read Hyprland workspace animations: " + e);
            return null;
        }
    }

    // Everything Altair overrides, e.g. once the originals are known.
    function applyAll(): void {
        applyBlur();
        applyBorders();
        applyResize();
        applySmooth();
        applyOpacity();
        applyWorkspaces();
    }

    function readOriginal(): void {
        reading = true;
        reader.running = true;
    }

    // Get a guaranteed-clean read: reload the user's config; the
    // "configreloaded" event then reads it (see Connections below).
    function cleanRead(): void {
        reading = true;
        Quickshell.execDetached(["hyprctl", "reload", "config-only"]);
        cleanReadFallback.restart();
    }
    // In case the reload event never arrives.
    Timer {
        id: cleanReadFallback
        interval: 3000
        onTriggered: if (root.reading && !reader.running) root.readOriginal()
    }

    Process {
        id: reader
        command: ["sh", "-c", "for o in general:border_size general:col.active_border general:col.inactive_border decoration:blur:size decoration:blur:passes general:resize_on_border misc:animate_manual_resizes misc:animate_mouse_windowdragging decoration:active_opacity decoration:inactive_opacity; do hyprctl getoption \"$o\" | head -n1; done; hyprctl animations -j | tr -d '\\n'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const l = this.text.trim().split("\n");
                if (l.length < 11) {
                    console.warn("altair: could not read Hyprland options: " + this.text);
                    root.reading = false;
                    return;
                }
                const int = s => parseInt(s.replace(/^.*?:\s*/, ""));
                root.original = {
                    borderSize: int(l[0]),
                    active: root.gradientToLua(l[1]),
                    inactive: root.gradientToLua(l[2]),
                    blurSize: int(l[3]),
                    blurPasses: int(l[4]),
                    resizeOnBorder: /true|:\s*1/.test(l[5]),
                    animResize: /true|:\s*1/.test(l[6]),
                    animDrag: /true|:\s*1/.test(l[7]),
                    activeOpacity: parseFloat(l[8].replace(/^.*?:\s*/, "")) || 1,
                    inactiveOpacity: parseFloat(l[9].replace(/^.*?:\s*/, "")) || 1,
                    // readerGuard: if a read still sees Altair's own curves
                    // (e.g. two shell instances overlapping during a hot reload,
                    // one applying while the other reads), keep what we had.
                    moveAnim: root.moveAnimFrom(l.slice(10).join("")) ?? root.original?.moveAnim
                        ?? { enabled: true, speed: 5, curve: 'bezier = "default"' },
                    wsAnim: root.wsAnimFrom(l.slice(10).join("")) ?? root.original?.wsAnim ?? null
                };
                root.reading = false;
                cleanReadFallback.stop();
                store.session = root.session;
                store.values = root.original;
                root.applyAll();
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
            // (Records from older versions lack some values: read again.)
            if (store.session === root.session && store.values && store.values.moveAnim !== undefined
                    && store.values.activeOpacity !== undefined && store.values.wsAnim !== undefined) {
                root.original = store.values;
                root.applyAll();
            } else {
                // No (complete) record for this Hyprland session.
                root.cleanRead();
            }
        }
        onLoadFailed: root.cleanRead()

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

    // Give our floating window with this title this size, and centre it.
    function resetWindowByTitle(title: string, width: int, height: int): void {
        const t = Hyprland.toplevels.values.find(t => t.title === title);
        if (t)
            resetWindow(t.address, width, height);
    }

    // Our (first) window with this title, or null.
    function windowByTitle(title: string): var {
        return Hyprland.toplevels.values.find(t => t.title === title) ?? null;
    }

    // Move a floating window to exact global layout coordinates, instantly.
    function moveWindow(address: string, x: int, y: int): void {
        const w = `address:${address.startsWith("0x") ? address : "0x" + address}`;
        Hyprland.dispatch(`hl.dsp.window.move({ window = "${w}", x = ${x}, y = ${y} })`);
    }

    // Centre our floating window with this title, keeping its size, gliding
    // there. The Settings window has no_anim (see hypr/init.lua: Hyprland's
    // open animation fought our own fade-in), which also makes moves jump, so
    // no_anim is lifted just for the move and set again afterwards. The glide
    // uses Hyprland's "windowsMove" animation (Altair's calm curve when
    // Settings > Windows > Smooth resizing is on, else your own).
    function centerWindowByTitle(title: string): void {
        const t = Hyprland.toplevels.values.find(t => t.title === title);
        if (!t)
            return;
        const w = `address:${t.address.startsWith("0x") ? t.address : "0x" + t.address}`;
        allowAnimation(w);
        Hyprland.dispatch(`hl.dsp.window.center({ window = "${w}" })`);
    }

    // Lift no_anim on a window (selector "address:0x…") for the next move or
    // resize; set again by the timer below. No-op when animations are off.
    function allowAnimation(w: string): void {
        if (!Theme.animations)
            return;
        Hyprland.dispatch(`hl.dsp.window.set_prop({ window = "${w}", prop = "no_anim", value = "0" })`);
        restoreNoAnim.window = w;
        restoreNoAnim.restart();
    }
    Timer {
        id: restoreNoAnim
        property string window
        interval: 900   // longer than any sensible windowsMove animation
        onTriggered: Hyprland.dispatch(`hl.dsp.window.set_prop({ window = "${window}", prop = "no_anim", value = "1" })`)
    }

    // Give a floating window this size and centre it. address: from
    // HyprlandToplevel (with or without "0x").
    function resetWindow(address: string, width: int, height: int): void {
        const w = `address:${address.startsWith("0x") ? address : "0x" + address}`;
        allowAnimation(w);   // glide (see centerWindowByTitle)
        Hyprland.dispatch(`hl.dsp.window.resize({ window = "${w}", x = ${width}, y = ${height} })`);
        Hyprland.dispatch(`hl.dsp.window.center({ window = "${w}" })`);
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
