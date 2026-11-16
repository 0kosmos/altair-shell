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
// A drag:  begin(monitor, radius, startRect) -> update(rawRect, free) on every
// pointer move -> end(). Follow `rect` (onRectChanged) to place the thing; it
// keeps moving for a moment after end() while it settles, then `settled(rect)`
// fires with the final position. components/DragOverlay.qml shows the dim and
// guides from this state. Nothing runs when nothing is dragged.
//
// Feel:
//   - `target` is where the thing should be: the pointer position, pulled
//     onto a nearby line (screen edges and centres, the bar, other widgets);
//   - `rect` follows `target` smoothly every frame (exponential easing, time
//     constant `tau`), so following the pointer, catching a line and letting
//     go of it all glide instead of jump;
//   - lines catch within `engage` px, only while moving slowly (`maxSpeed`),
//     and let go beyond `release` px (no flicker at the edge of the zone);
//   - the grid applies on drop only: the thing glides onto the nearest grid
//     point when released, instead of stepping while dragged.
Singleton {
    id: root

    signal settled(var rect)

    // ---- Options ----------------------------------------------------------------
    readonly property bool enabled: Config.ready ? Config.windows.snapping : true
    readonly property int grid: Config.ready && [4, 8, 16].indexOf(Config.windows.grid) !== -1 ? Config.windows.grid : 0
    readonly property int engage: 8
    readonly property int release: 20
    readonly property real maxSpeed: 900       // px/s
    readonly property real tau: 0.055          // s; higher = smoother but trails more

    // ---- State (read by DragOverlay and the dragged thing) ---------------------
    property bool dragging: false              // pointer is down
    property bool settling: false              // released, gliding to rest
    readonly property bool moving: dragging || settling
    property string screenName: ""
    property var monitor: null                 // { x, y, w, h }
    property var usable: null                  // monitor minus reserved space (the bar)
    property real radius: 18                   // corner radius of the dragged thing
    property bool dim: true                    // DragOverlay dims the screen (off in widget edit mode, which dims already)

    property var raw: null                     // where the pointer puts it
    property var lineX: null                   // current snap { line, off } per axis, or null
    property var lineY: null
    property var target: null                  // where it should be
    property var rect: null                    // where it is (follows target smoothly)

    readonly property var guidesX: lineX ? [lineX.line] : []
    readonly property var guidesY: lineY ? [lineY.line] : []

    // Other things to align with: [{ x, y, w, h }] (desktop widgets register here).
    property var targets: []
    // A spot the dragged thing is pulled into instead of following the
    // pointer (e.g. a widget's magnetic attach slot), or null. It still
    // glides there smoothly.
    property var pin: null

    property real speed: 0
    property real lastT: 0
    // Exact (unrounded) smoothed position.
    property real fx: 0
    property real fy: 0

    // Runs only while something is dragged or settling.
    FrameAnimation {
        running: root.moving
        onTriggered: root.step(frameTime)
    }

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

    // How far the dragged thing's group sticks out past its rect
    // ({ l, t, r, b } in px): the whole group is kept on screen.
    property var extent: ({ l: 0, t: 0, r: 0, b: 0 })
    property var avoiding: null

    // Things desktop widgets keep clear of on a monitor, as rects relative
    // to it, each grown by `gap`: the bar's strip and the dock.
    readonly property int widgetGap: 12
    function obstacles(monitor: string, w: real, h: real): var {
        const g = widgetGap;
        const t = Theme.barGap + Theme.barThickness + g;
        const l = [];
        // While the bar is dragged: where it would go (widgets preview it).
        switch (ShellState.barDragTarget || Theme.barPosition) {
        case "top": l.push({ x: -1e4, y: -1e4, w: 3e4, h: 1e4 + t }); break;
        case "bottom": l.push({ x: -1e4, y: h - t, w: 3e4, h: 1e4 }); break;
        case "left": l.push({ x: -1e4, y: -1e4, w: 1e4 + t, h: 3e4 }); break;
        case "right": l.push({ x: w - t, y: -1e4, w: 1e4, h: 3e4 }); break;
        }
        const d = DockApps.rects[monitor];
        if (d)
            l.push({ x: d.x - g, y: d.y - g, w: d.w + 2 * g, h: d.h + 2 * g });
        return l;
    }

    // The nearest spot for rect `g` ({ x, y, w, h }) inside `b` (the bounds)
    // that is clear of every obstacle at once, or null if there is none.
    // Candidates: where it is, and against each edge of every obstacle and
    // of the bounds, in every combination (a handful of obstacles, so a few
    // dozen checks). Pushing out of one obstacle after another could land
    // in the next one (e.g. under the bar when the dock is beside it).
    function fit(g: var, obstacles: var, b: var): var {
        const xs = [g.x, b.x, b.x + b.w - g.w], ys = [g.y, b.y, b.y + b.h - g.h];
        for (const o of obstacles) {
            xs.push(o.x - g.w, o.x + o.w);
            ys.push(o.y - g.h, o.y + o.h);
        }
        const clear = (x, y) => x >= b.x - 0.5 && y >= b.y - 0.5 && x + g.w <= b.x + b.w + 0.5 && y + g.h <= b.y + b.h + 0.5
            && obstacles.every(o => x >= o.x + o.w || x + g.w <= o.x || y >= o.y + o.h || y + g.h <= o.y);
        let best = null, bestD = 1e18;
        for (const x of xs) {
            for (const y of ys) {
                const d = (x - g.x) * (x - g.x) + (y - g.y) * (y - g.y);
                if (d < bestD && clear(x, y)) {
                    best = { x, y };
                    bestD = d;
                }
            }
        }
        return best;
    }

    // Move ({ x, y }) that gets `g` clear of the obstacles (see fit); no move
    // if it can't be (it stays where it is).
    function avoid(g: var, obstacles: var, b: var): var {
        const p = fit(g, obstacles, b);
        return p ? { x: p.x - g.x, y: p.y - g.y } : { x: 0, y: 0 };
    }

    // opts (optional): { targets: [{ x, y, w, h }] to align with, dim: false,
    // extent: { l, t, r, b } }
    function begin(mon: var, radius: real, start: var, opts: var): void {
        targets = opts?.targets ?? [];
        extent = opts?.extent ?? { l: 0, t: 0, r: 0, b: 0 };
        // Widgets: the whole monitor, keeping clear of the bar and dock
        // (obstacles, global coordinates); windows: the usable area.
        avoiding = opts?.avoid ? obstacles(mon.name, mon.w, mon.h).map(o => ({ x: o.x + mon.x, y: o.y + mon.y, w: o.w, h: o.h })) : null;
        dim = opts?.dim ?? true;
        screenName = mon.name;
        monitor = { x: mon.x, y: mon.y, w: mon.w, h: mon.h };
        usable = mon.usable;
        root.radius = radius;
        lineX = lineY = null;
        pin = null;
        speed = 0;
        lastT = Date.now();
        raw = start;
        target = clamp(start);
        fx = target.x;
        fy = target.y;
        rect = { x: Math.round(fx), y: Math.round(fy), w: target.w, h: target.h };
        settling = false;
        dragging = true;
    }

    // Released: glide onto the grid (if any) and settle.
    function end(): void {
        if (!dragging)
            return;
        dragging = false;
        lineX = lineY = null;
        let t = target;
        if (grid > 0 && enabled && !pin)
            t = clamp({ x: usable.x + Math.round((t.x - usable.x) / grid) * grid,
                        y: usable.y + Math.round((t.y - usable.y) / grid) * grid, w: t.w, h: t.h });
        target = t;
        settling = true;
        if (!Theme.animations)
            step(1);
    }

    // The pointer moved: `r` is where it puts the thing ({ x, y, w, h }).
    // `free` (Shift held) lets go of / skips snapping.
    function update(r: var, free: bool): void {
        if (!dragging)
            return;
        const now = Date.now();
        const dt = Math.max(1, now - lastT) / 1000;
        speed = speed * 0.6 + (Math.hypot(r.x - raw.x, r.y - raw.y) / dt) * 0.4;
        lastT = now;
        raw = r;

        if (pin) {
            if (lineX) lineX = null;
            if (lineY) lineY = null;
            target = clamp(pin);
            if (!Theme.animations)
                step(1);
            return;
        }
        const on = enabled && !free;
        const nx = axis(lineX, on, r.x, r.w, linesX());
        const ny = axis(lineY, on, r.y, r.h, linesY());
        // Assigned only on change (the guides are rebuilt on change).
        if (nx !== lineX) lineX = nx;
        if (ny !== lineY) lineY = ny;
        target = clamp({ x: lineX ? lineX.line - lineX.off : r.x, y: lineY ? lineY.line - lineY.off : r.y, w: r.w, h: r.h });
        if (!Theme.animations)
            step(1);
    }

    // Change the pin while dragging (e.g. on entering/leaving a magnet slot).
    function setPin(r: var): void {
        pin = r;
        if (dragging && raw)
            update(raw, false);
    }

    // One frame of smoothing towards `target`.
    function step(dt: real): void {
        if (!target)
            return;
        const a = Theme.animations ? 1 - Math.exp(-Math.max(0, dt) / tau) : 1;
        fx += (target.x - fx) * a;
        fy += (target.y - fy) * a;
        const done = Math.abs(target.x - fx) < 0.5 && Math.abs(target.y - fy) < 0.5;
        if (done) {
            fx = target.x;
            fy = target.y;
        }
        const x = Math.round(fx), y = Math.round(fy);
        if (!rect || rect.x !== x || rect.y !== y || rect.w !== target.w || rect.h !== target.h)
            rect = { x, y, w: target.w, h: target.h };
        if (settling && done) {
            settling = false;
            settled(rect);
        }
    }

    // One axis: keep the current line while within `release`, else catch the
    // nearest within `engage` (only when moving slowly), else none.
    function axis(cur: var, on: bool, pos: real, size: real, lines: var): var {
        if (!on)
            return null;
        if (cur && Math.abs(pos + cur.off - cur.line) <= release)
            return cur;
        return speed < maxSpeed ? nearest(pos, size, lines) : null;
    }

    function clamp(r: var): var {
        const e = extent;
        const b = avoiding ? monitor : usable;
        const x = Math.max(b.x + e.l, Math.min(b.x + b.w - r.w - e.r, r.x));
        const y = Math.max(b.y + e.t, Math.min(b.y + b.h - r.h - e.b, r.y));
        if (!avoiding)
            return { x, y, w: r.w, h: r.h };
        const d = avoid({ x: x - e.l, y: y - e.t, w: r.w + e.l + e.r, h: r.h + e.t + e.b }, avoiding, b);
        return { x: x + d.x, y: y + d.y, w: r.w, h: r.h };
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
