// SPDX-License-Identifier: GPL-3.0-or-later
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.core
import qs.theme

// Per-app window transparency, as Hyprland window rules.
//
// Mechanism: named Lua window rules sent with `hyprctl eval` (Hyprland 0.57).
//   - Sending a rule with an existing name replaces it, and Hyprland updates
//     open windows right away, so sliders apply live.
//   - The rules live only in the running compositor. A config reload or a new
//     login drops them, so they are re-sent on start and after every reload,
//     and nothing ever has to be removed from hyprland.lua on uninstall.
//   - "override" makes a rule's opacity replace the default opacity (Hyprland
//     would otherwise multiply the two).
// The default opacity for all windows is a plain option, see Hypr.applyOpacity.
Singleton {
    id: root

    // (JsonAdapter hands a `var` list over as a Qt list, not a JS array.)
    readonly property var rules: {
        const r = Config.ready ? Config.transparency.rules : null;
        return r && typeof r === "object" && r.length !== undefined ? Array.from(r) : [];
    }
    readonly property bool lowPower: Theme.lowPower
    readonly property bool defaultSet: Config.ready
        && (Config.transparency.activeOpacity > 0 || Config.transparency.inactiveOpacity > 0)

    // Ready-made rules, offered in Settings with one click.
    readonly property var suggestions: [
        { name: "kitty", match: "^kitty$", opacity: 0.9, inactiveOpacity: 0.85, blur: true, enabled: true },
        { name: "Spotify", match: "^([Ss]potify|com\\.spotify\\.Client)$", opacity: 0.95, inactiveOpacity: 0.9, blur: true, enabled: true },
        { name: "Discord", match: "^(discord|vesktop|com\\.discordapp\\.Discord)$", opacity: 0.95, inactiveOpacity: 0.9, blur: true, enabled: true },
        { name: "Firefox", match: "^(firefox|org\\.mozilla\\.firefox)$", opacity: 0.97, inactiveOpacity: 0.92, blur: true, enabled: true },
        { name: "Dolphin", match: "^org\\.kde\\.dolphin$", opacity: 0.92, inactiveOpacity: 0.88, blur: true, enabled: true },
    ]

    // How many "altair-opacity-<n>" rules we have sent since Hyprland's last
    // reload; rules beyond the current list are switched off. Starts at 16:
    // a previous run of the shell may have sent more rules than the config
    // now has (e.g. edited while the shell was stopped).
    property int sent: 16

    onRulesChanged: Qt.callLater(apply)
    onLowPowerChanged: Qt.callLater(apply)
    onDefaultSetChanged: Qt.callLater(apply)
    Component.onCompleted: Qt.callLater(apply)

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            // Hyprland re-read its config and dropped our rules: send them again.
            if (event.name === "configreloaded") {
                root.sent = 0;
                Qt.callLater(root.apply);
            }
        }
    }

    function apply(): void {
        if (!Config.ready)
            return;
        const lua = [];
        let any = false;
        rules.forEach((r, i) => {
            const on = r.enabled !== false && !!r.match;
            any = any || on;
            const a = clamp(r.opacity), ia = clamp(r.inactiveOpacity);
            // Low-power mode keeps the opacity but turns blur behind it off.
            const noBlur = lowPower || r.blur === false;
            lua.push(`hl.window_rule({ name = "altair-opacity-${i}", enabled = ${on}, `
                + `match = { class = ${luaString(r.match || "^$")} }, `
                + `opacity = "${a} override ${ia} override", no_blur = ${noBlur} })`);
        });
        for (let i = rules.length; i < sent; i++)
            lua.push(`hl.window_rule({ name = "altair-opacity-${i}", enabled = false, match = { class = "^$" } })`);
        // Low-power mode: no blur behind see-through windows at all, also for
        // those using the default opacity. Sent last so it wins.
        const lp = lowPower && (any || defaultSet);
        if (lp || sent > 0)
            lua.push(`hl.window_rule({ name = "altair-opacity-lowpower", enabled = ${lp}, match = { class = ".*" }, no_blur = true })`);
        sent = rules.length;
        if (lua.length)
            Quickshell.execDetached(["hyprctl", "eval", lua.join(" ")]);
    }

    function clamp(v: real): real {
        const n = Number(v);
        return isNaN(n) ? 1 : Math.round(Math.max(0.3, Math.min(1, n)) * 100) / 100;
    }

    // ---- Editing (used by the Settings page) --------------------------------
    // The list is replaced as a whole so JsonAdapter notices and saves it.
    function set(i: int, changes: var): void {
        const list = rules.slice();
        list[i] = Object.assign({}, list[i], changes);
        Config.transparency.rules = list;
    }
    function remove(i: int): void {
        const list = rules.slice();
        list.splice(i, 1);
        Config.transparency.rules = list;
    }
    function add(rule: var): void {
        if (!rule.match || hasMatch(rule.match))
            return;
        Config.transparency.rules = rules.concat([Object.assign({}, rule)]);
    }
    // A rule for exactly this window class (as shown by `hyprctl clients`).
    function addClass(cls: string): void {
        cls = cls.trim();
        if (cls)
            add({ name: cls, match: "^" + escapeRegex(cls) + "$", opacity: 0.9, inactiveOpacity: 0.85, blur: true, enabled: true });
    }
    function hasMatch(match: string): bool {
        return rules.some(r => r.match === match);
    }
    // Whether some rule already covers this window class.
    function covers(cls: string): bool {
        return rules.some(r => {
            try {
                return new RegExp(r.match).test(cls);
            } catch (e) {
                return false;
            }
        });
    }

    function escapeRegex(s: string): string {
        return s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
    }
    function luaString(s: string): string {
        return '"' + s.replace(/\\/g, "\\\\").replace(/"/g, '\\"').replace(/\n/g, "\\n") + '"';
    }
}
