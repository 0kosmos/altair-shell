// SPDX-License-Identifier: GPL-3.0-or-later
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.core
import qs.theme

// Shared drag/snap logic (Settings window now, desktop widgets later).
//
// All rectangles are in Hyprland's global layout coordinates (logical px).
// A drag:  begin(monitor) -> update(rawRect, free) on every pointer move ->
// end(). Read the placed rectangle from `rect` (it changes on its own while a
// snap glides in or out, so follow onRectChanged). While a drag runs,
// components/DragOverlay.qml shows the dim and guides from this state; when
// nothing is dragged this costs nothing.
//
// How snapping feels:
//   - glide: the thing eases onto a line (and back to the pointer when it lets
//     go) over `glideMs` instead of jumping;
//   - hysteresis: catches within `engage` px, lets go only beyond `release` px,
//     so it never flickers at the edge of the snap zone;
//   - speed: only catches when moving slower than `maxSpeed`, so sweeping
//     across the screen doesn't stick to every line on the way.
Singleton {
    id: root

    // ---- Options ----------------------------------------------------------------
    readonly property bool enabled: Config.ready ? Config.windows.snapping : true
    readonly property int grid: Config.ready ? Math.max(0, Config.windows.grid) : 0
    readonly property int engage: 8
    readonly property int release: 16
    readonly property real maxSpeed: 1400      // px/s
    readonly property int glideMs: Theme.animations ? 180 : 0

    // ---- Drag state (read by DragOverlay) ---------------------------------------
    property bool dragging: false
    property string screenName: ""
    property var monitor: null          // { x, y, w, h }
    property var usable: null           // monitor minus reserved space (the bar)
    property real radius: 18            // corner radius of the dragged thing

    property var raw: null              // where the pointer puts it (unsnapped)
    // Current snap per axis: { line, off } (off = 0 / size/2 / size: which of
    // start / centre / end sits on the line), or null. `held*` is the last
    // one, kept while the snap glides out.
    property var lineX: null
    property var lineY: null
    property var heldX: null
    property var heldY: null
    // 0 = follows the pointer, 1 = on the line; animated.
    property real kx: 0
    property real ky: 0

    readonly property var guidesX: lineX ? [lineX.line] : []
    readonly property var guidesY: lineY ? [lineY.line] : []

    // The placed rectangle: pointer position blended towards the snap line,
    // else the grid, kept inside the usable area (never under the bar).
    readonly property var rect: {
        if (!raw || !usable)
            return null;
        const gx = grid > 0 && enabled ? usable.x + Math.round((raw.x - usable.x) / grid) * grid : raw.x;
        const gy = grid > 0 && enabled ? usable.y + Math.round((raw.y - usable.y) / grid) * grid : raw.y;
        let x = heldX ? gx + kx * (heldX.line - heldX.off - gx) : gx;
        let y = heldY ? gy + ky * (heldY.line - heldY.off - gy) : gy;
        x = Math.max(usable.x, Math.min(usable.x + usable.w - raw.w, x));
        y = Math.max(usable.y, Math.min(usable.y + usable.h - raw.h, y));
        return { x: Math.round(x), y: Math.round(y), w: raw.w, h: raw.h };
    }

    // Other things to align with: [{ x, y, w, h }] (desktop widgets register here).
    property var targets: []

    NumberAnimation { id: animX; target: root; property: "kx"; duration: root.glideMs; easing.type: Easing.OutCubic }
    NumberAnimation { id: animY; target: root; property: "ky"; duration: root.glideMs; easing.type: Easing.OutCubic }

    // Pointer speed, smoothed a little.
    property real speed: 0
    property real lastT: 0

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

    function begin(mon: var, radius: real, start: var): void {
        animX.stop();
        animY.stop();
        screenName = mon.name;
        monitor = { x: mon.x, y: mon.y, w: mon.w, h: mon.h };
        usable = mon.usable;
        root.radius = radius;
        lineX = lineY = heldX = heldY = null;
        kx = ky = 0;
        speed = 0;
        lastT = Date.now();
        raw = start;
        dragging = true;
    }

    function end(): void {
        animX.stop();
        animY.stop();
        dragging = false;
        lineX = lineY = null;
    }

    // The pointer moved: `r` is where it puts the thing ({ x, y, w, h }).
    // `free` (Shift held) lets go of / skips snapping.
    function update(r: var, free: bool): void {
        const now = Date.now();
        if (raw) {
            const dt = Math.max(1, now - lastT) / 1000;
            const v = Math.hypot(r.x - raw.x, r.y - raw.y) / dt;
            speed = speed * 0.5 + v * 0.5;
        }
        lastT = now;
        raw = r;

        const on = enabled && !free;
        // Assigned only on change: the guides would otherwise be rebuilt (and
        // fade in again) on every pointer move.
        const nx = axis(lineX, on, r.x, r.w, linesX(), animX, "kx", "heldX");
        const ny = axis(lineY, on, r.y, r.h, linesY(), animY, "ky", "heldY");
        if (nx !== lineX) lineX = nx;
        if (ny !== lineY) lineY = ny;
    }

    // One axis: keep the current snap while within `release`, else catch a new
    // line within `engage` (only when moving slowly), else let go. Starts the
    // glide in or out when that changes.
    function axis(cur: var, on: bool, pos: real, size: real, lines: var, anim: var, k: string, held: string): var {
        let next = null;
        if (on && cur && Math.abs(pos + cur.off - cur.line) <= release)
            next = cur;
        else if (on && speed < maxSpeed)
            next = nearest(pos, size, lines);

        const same = cur && next && cur.line === next.line && cur.off === next.off;
        if (!same) {
            if (next) {
                // New line: start the glide from where the thing is now.
                if (cur)
                    root[k] = 0;
                root[held] = next;
                anim.stop();
                anim.to = 1;
                anim.start();
            } else if (cur) {
                // Let go: glide back to the pointer (heldX/Y stays for that).
                anim.stop();
                anim.to = 0;
                anim.start();
            }
        }
        return next;
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

    // Nearest line within `engage` of the interval's start, centre or end.
    function nearest(pos: real, size: real, lines: var): var {
        let best = null;
        for (const line of lines) {
            for (const off of [0, size / 2, size]) {
                const d = Math.abs(pos + off - line);
                if (d <= engage && (!best || d < best.d))
                    best = { d, line, off };
            }
        }
        return best ? { line: best.line, off: best.off } : null;
    }
}
