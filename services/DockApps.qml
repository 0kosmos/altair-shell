// SPDX-License-Identifier: GPL-3.0-or-later
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.core

// What the dock shows: pinned apps (Config.dock.pinned, in order), then
// running apps that aren't pinned. Running windows come from Hyprland's
// toplevel list (event-driven; nothing polls) and are grouped by app id.
//
// Matching windows to apps: the window's Wayland app id goes through
// DesktopEntries.heuristicLookup (desktop id, StartupWMClass, lowercase
// name...). A window without a matching .desktop file still gets an item
// (keyed by its app id), but it can't be pinned or relaunched.
Singleton {
    id: root

    readonly property bool enabled: Config.ready && Config.dock.enabled
    readonly property list<string> pinned: Config.ready ? Array.from(Config.dock.pinned ?? []).filter(x => typeof x === "string") : []

    // App id of a window: the live Wayland one when available, else Hyprland's
    // class from the last IPC refresh.
    function appIdOf(t: var): string {
        return t?.wayland?.appId || t?.lastIpcObject?.class || "";
    }

    // Desktop entry for an app id, or null. Cached: heuristicLookup walks
    // all entries, and this runs whenever a window opens or closes.
    property var lookupCache: ({})
    function entryFor(appId: string): var {
        if (!appId)
            return null;
        if (lookupCache[appId] === undefined)
            lookupCache[appId] = DesktopEntries.heuristicLookup(appId) ?? null;
        return lookupCache[appId];
    }
    // Apps installed/removed: drop the cache (entries may have changed).
    Connections {
        target: DesktopEntries.applications
        function onValuesChanged() {
            root.lookupCache = {};
        }
    }

    // [{ key, entry, appId, windows: [HyprlandToplevel], pinned }]
    // key = desktop id, or "app:<app id>" without a desktop entry.
    readonly property var items: {
        if (!enabled)
            return [];
        void lookupCache;   // re-run after the cache was dropped
        const groups = {};
        const order = [];
        for (const t of Hyprland.toplevels.values) {
            const appId = appIdOf(t);
            if (!appId || t.lastIpcObject?.mapped === false)
                continue;
            const entry = entryFor(appId);
            const key = entry ? entry.id : "app:" + appId.toLowerCase();
            if (!groups[key]) {
                groups[key] = { key, entry, appId, windows: [], pinned: false };
                order.push(key);
            }
            groups[key].windows.push(t);
        }
        const result = [];
        for (const id of pinned) {
            const g = groups[id];
            if (g) {
                g.pinned = true;
                result.push(g);
                delete groups[id];
            } else {
                const entry = DesktopEntries.byId(id);
                if (entry)   // uninstalled apps simply disappear from the dock
                    result.push({ key: id, entry, appId: "", windows: [], pinned: true });
            }
        }
        for (const key of order)
            if (groups[key])
                result.push(groups[key]);
        // Recent / most used apps that are neither pinned nor running.
        if (showRecent) {
            const taken = new Set(result.map(i => i.key));
            let n = 0;
            for (const id of recentCandidates) {
                if (n >= recentCount)
                    break;
                if (taken.has(id))
                    continue;
                const entry = DesktopEntries.byId(id);
                if (!entry || entry.noDisplay)
                    continue;
                result.push({ key: id, entry, appId: "", windows: [], pinned: false, recent: true });
                taken.add(id);
                n++;
            }
        }
        return result;
    }
    readonly property int pinnedCount: items.filter(i => i.pinned).length
    readonly property int recentShown: items.filter(i => i.recent).length
    readonly property int runningCount: items.length - pinnedCount - recentShown

    // ---- Recent and most used apps ----------------------------------------------
    // "Recent" = apps you focused or started lately (most recent first), then
    // the launcher's most launched apps fill up the remaining places.
    readonly property bool showRecent: Config.ready && Config.dock.recentApps
    readonly property int recentCount: Math.max(1, Math.min(6, Config.dock.recentCount || 3))
    readonly property var recentCandidates: {
        const seen = new Set();
        const out = [];
        for (const id of Array.from(state.recent ?? []))
            if (typeof id === "string" && !seen.has(id)) {
                seen.add(id);
                out.push(id);
            }
        const l = Apps.launches;
        for (const id of Object.keys(l).sort((a, b) => l[b] - l[a]))
            if (!seen.has(id)) {
                seen.add(id);
                out.push(id);
            }
        return out;
    }

    function touch(id: string): void {
        if (!id || id.startsWith("app:"))
            return;
        const cur = Array.from(state.recent ?? []);
        if (cur[0] === id)
            return;
        state.recent = [id].concat(cur.filter(x => x !== id)).slice(0, 20);
    }

    // Focus changes are events anyway; recording them costs nothing.
    Connections {
        target: Hyprland
        enabled: root.enabled && root.showRecent
        function onActiveToplevelChanged() {
            const e = root.entryFor(root.appIdOf(Hyprland.activeToplevel));
            if (e)
                root.touch(e.id);
        }
    }

    function clearRecent(): void {
        state.recent = [];
    }

    FileView {
        path: Apps.stateDir + "/dock.json"
        onAdapterUpdated: writeAdapter()
        printErrors: false   // missing on first run
        JsonAdapter {
            id: state
            property var recent: []
        }
    }

    // The dock's rectangle per monitor ({ x, y, w, h } relative to the
    // monitor, at rest), or missing while it is off or auto-hiding. Desktop
    // widgets keep clear of it (ShellState.obstacles).
    property var rects: ({})
    function setRect(monitor: string, r: var): void {
        const cur = rects[monitor] ?? null;
        if (JSON.stringify(cur) === JSON.stringify(r))
            return;
        const next = Object.assign({}, rects);
        if (r)
            next[monitor] = r;
        else
            delete next[monitor];
        rects = next;
    }

    // Show an auto-hidden dock for a moment (IPC "dock peek", keybinds).
    property bool peeking: false
    function peek(): void {
        peeking = true;
        peekTimer.restart();
    }
    Timer {
        id: peekTimer
        interval: 2000
        onTriggered: root.peeking = false
    }

    // ---- Actions ------------------------------------------------------------

    function address(t: var): string {
        return t.address.startsWith("0x") ? t.address : "0x" + t.address;
    }

    // Click: start the app if it isn't running; otherwise focus its window,
    // or cycle to the next one if one of its windows already has focus.
    function activate(item: var): void {
        if (item.windows.length === 0) {
            launch(item);
            return;
        }
        const ws = item.windows.slice().sort((a, b) => a.address.localeCompare(b.address));
        const cur = ws.indexOf(Hyprland.activeToplevel);
        focus(ws[(cur + 1) % ws.length]);
    }

    function focus(t: var): void {
        // Focusing a window also switches to its workspace.
        Hyprland.dispatch(`hl.dsp.focus({ window = "address:${address(t)}" })`);
    }

    function launch(item: var): void {
        if (item.entry) {
            Apps.launch(item.entry);
            touch(item.entry.id);
        }
    }

    function close(t: var): void {
        if (t.wayland)
            t.wayland.close();   // polite close request (the app may ask to save)
    }

    function closeAll(item: var): void {
        for (const t of item.windows)
            close(t);
    }

    function setPinned(list: var): void {
        Config.dock.pinned = Array.from(list);
    }

    function pin(id: string, at: int): void {
        const l = pinned.filter(x => x !== id);
        l.splice(at < 0 ? l.length : Math.min(at, l.length), 0, id);
        setPinned(l);
    }

    function unpin(id: string): void {
        setPinned(pinned.filter(x => x !== id));
    }

    // Move a pinned app to position `to` among the pinned apps.
    function move(id: string, to: int): void {
        pin(id, to);
    }
}
