// SPDX-License-Identifier: GPL-3.0-or-later
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.core

// Shared drag/snap logic (Settings window now, desktop widgets later).
//
// All rectangles are in Hyprland's global layout coordinates (logical px).
// A drag:  begin(monitor) -> place(rect, free) for every move -> end().
// While a drag runs, components/DragOverlay.qml shows the dim and guides from
// the state below; when nothing is dragged this costs nothing.
Singleton {
    id: root

    // ---- Options ----------------------------------------------------------------
    readonly property bool enabled: Config.ready ? Config.windows.snapping : true
    readonly property int threshold: 8
    readonly property int grid: Config.ready ? Math.max(0, Config.windows.grid) : 0

    // ---- Drag state (read by DragOverlay) ---------------------------------------
    property bool dragging: false
    property string screenName: ""
    property var monitor: null          // { x, y, w, h }
    property var usable: null           // monitor minus reserved space (the bar)
    property var rect: null             // dragged rect, as placed
    property real radius: 18            // corner radius of the dragged thing
    property var guidesX: []            // vertical lines snapped to (global x)
    property var guidesY: []            // horizontal lines snapped to (global y)

    // Other things to align with: [{ x, y, w, h }] (desktop widgets register here).
    property var targets: []

    // The Hyprland monitor as { name, x, y, w, h, usable }.
    // Position, size and scale are always known; the reserved space (the bar)
    // and rotation come from lastIpcObject, which is only filled after
    // Hyprland.refreshMonitors() — callers refresh first.
    function monitorInfo(m: var): var {
        const o = m?.lastIpcObject ?? {};
        const s = m?.scale || 1;
        const w = Math.round((m?.width ?? 1920) / s), h = Math.round((m?.height ?? 1080) / s);
        // Rotated 90/270°: width and height swap.
        const rotated = (o.transform ?? 0) % 2 === 1;
        const mw = rotated ? h : w, mh = rotated ? w : h;
        const r = o.reserved ?? [0, 0, 0, 0];   // left, top, right, bottom
        const x = m?.x ?? 0, y = m?.y ?? 0;
        return {
            name: m?.name ?? "",
            x, y, w: mw, h: mh,
            usable: { x: x + r[0], y: y + r[1], w: mw - r[0] - r[2], h: mh - r[1] - r[3] }
        };
    }

    function begin(mon: var, radius: real): void {
        screenName = mon.name;
        monitor = { x: mon.x, y: mon.y, w: mon.w, h: mon.h };
        usable = mon.usable;
        root.radius = radius;
        guidesX = [];
        guidesY = [];
        dragging = true;
    }

    function end(): void {
        dragging = false;
        guidesX = [];
        guidesY = [];
    }

    // Where `r` ({ x, y, w, h }) should go: kept on the monitor, snapped to the
    // nearest line within `threshold` (edges and centres of the monitor, the
    // area below the bar, and other targets), else to the grid if one is set.
    // `free` (Shift held) skips snapping.
    function place(r: var, free: bool): var {
        let x = r.x, y = r.y;
        let gx = [], gy = [];
        if (enabled && !free) {
            const sx = snapAxis(x, r.w, linesX());
            const sy = snapAxis(y, r.h, linesY());
            if (sx) { x = sx.pos; gx = [sx.line]; }
            if (sy) { y = sy.pos; gy = [sy.line]; }
            if (grid > 0) {
                if (!sx) x = monitor.x + Math.round((x - monitor.x) / grid) * grid;
                if (!sy) y = monitor.y + Math.round((y - monitor.y) / grid) * grid;
            }
        }
        // Never (partly) off the monitor or under the bar.
        x = Math.max(usable.x, Math.min(usable.x + usable.w - r.w, x));
        y = Math.max(usable.y, Math.min(usable.y + usable.h - r.h, y));
        const placed = { x: Math.round(x), y: Math.round(y), w: r.w, h: r.h };
        rect = placed;
        // Only reassign when changed: the overlay redraws on change.
        if (JSON.stringify(gx) !== JSON.stringify(guidesX)) guidesX = gx;
        if (JSON.stringify(gy) !== JSON.stringify(guidesY)) guidesY = gy;
        return placed;
    }

    // Keep `r` fully inside a monitor's usable area (e.g. a saved position
    // after a resolution change).
    function clampTo(r: var, mon: var): var {
        const u = mon.usable;
        return {
            x: Math.round(Math.max(u.x, Math.min(u.x + u.w - r.w, r.x))),
            y: Math.round(Math.max(u.y, Math.min(u.y + u.h - r.h, r.y))),
            w: r.w, h: r.h
        };
    }

    function linesX(): var {
        const l = [monitor.x, monitor.x + monitor.w, monitor.x + monitor.w / 2, usable.x, usable.x + usable.w];
        for (const t of targets) l.push(t.x, t.x + t.w, t.x + t.w / 2);
        return l;
    }
    function linesY(): var {
        const l = [monitor.y, monitor.y + monitor.h, monitor.y + monitor.h / 2, usable.y, usable.y + usable.h];
        for (const t of targets) l.push(t.y, t.y + t.h, t.y + t.h / 2);
        return l;
    }

    // Best snap of an interval [pos, pos + size] (its start, centre or end) to
    // one of `lines`, or null.
    function snapAxis(pos: real, size: real, lines: var): var {
        let best = null;
        for (const line of lines) {
            for (const off of [0, size / 2, size]) {
                const d = Math.abs(pos + off - line);
                if (d <= threshold && (!best || d < best.d))
                    best = { d, pos: line - off, line };
            }
        }
        return best;
    }
}
