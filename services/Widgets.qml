// SPDX-License-Identifier: GPL-3.0-or-later
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.core

// Desktop widgets: the placed items (stored in config.json, widgets.items),
// the available types, and edit mode. Drawn by widgets/WidgetLayer.qml.
//
// An item: { id, type, monitor, x, y, scale, opacity, style, attachedTo, attachSide }
//   style       one of the type's `styles` ids (missing = the first)
//   vis         Music only: built-in visualizer ("off", "ring", "glow",
//               "bars", "wave", "mirror"; what a style offers: its `vis`)
//   attachedTo  id of the widget it hangs on (Visualizer/Equalizer on Music,
//               see widgets/WidgetFrame.qml); its x/y/scale then only matter
//               once it is detached
//   attachSide  which side of that widget: "bottom" (default), "top",
//               "left", "right"
//   x, y     position relative to the monitor's top-left (logical px)
//   scale    0.5 – 2.5 (size = the type's base size × scale)
//   opacity  0.2 – 1
Singleton {
    id: root

    // At most this many widgets of each type (all monitors together).
    readonly property int maxPerType: 2

    // Edit mode (runtime only): widgets above the windows, with handles.
    property bool editing: false
    onEditingChanged: {
        selected = "";
        selecting = false;
        picked = [];
        layerSettled = false;
        if (!editing)
            settleTimer.restart();
    }
    // True a moment after leaving edit mode, once the widget layer is back on
    // the Bottom layer. Widget overlays (FrameOverlay) are only created then:
    // Hyprland puts a surface that changes layer on top of that layer, so an
    // overlay made earlier would end up under the widgets' blurred glass.
    property bool layerSettled: true
    Timer {
        id: settleTimer
        interval: 600
        onTriggered: root.layerSettled = !root.editing
    }

    // ---- Edit mode tools (EditDock toolbar) ----------------------------------------
    // Select: click widgets to pick several; drag one of them to move them all,
    // or delete them together.
    property bool selecting: false
    onSelectingChanged: if (!selecting) picked = []
    property var picked: []
    function isPicked(id: string): bool {
        return picked.indexOf(id) !== -1;
    }
    function togglePick(id: string): void {
        picked = isPicked(id) ? picked.filter(x => x !== id) : picked.concat([id]);
    }
    // While a picked widget is dragged: how far it has moved ({ x, y }), so
    // the other picked ones follow it live.
    property var groupDelta: null
    function movePicked(dx: real, dy: real, except: string): void {
        save(items.map(i => isPicked(i.id) && i.id !== except && !i.attachedTo
            ? Object.assign({}, i, { x: Math.round(i.x + dx), y: Math.round(i.y + dy) }) : i));
    }
    function removePicked(): void {
        // Widgets attached to a removed one come loose and stay.
        const gone = new Set(picked);
        save(items.filter(i => !gone.has(i.id)).map(i => gone.has(i.attachedTo)
            ? Object.assign({}, i, { attachedTo: "", attachSide: "bottom" }) : i));
        picked = [];
    }
    function clearAll(): void {
        save([]);
        picked = [];
    }

    // Undo: the layouts before the last changes (this session, up to 30).
    // Consecutive saves within 600 ms (one drag: detach + drop) count as one.
    // Redo: what Undo took back (cleared by any new change).
    property var history: []
    property var future: []
    property real lastSave: 0
    readonly property bool canUndo: history.length > 0
    readonly property bool canRedo: future.length > 0
    property bool undoing: false
    function snapshot(): var {
        return JSON.parse(JSON.stringify(items));
    }
    function undo(): void {
        if (history.length === 0)
            return;
        future = future.concat([snapshot()]);
        restore(history[history.length - 1]);
        history = history.slice(0, -1);
    }
    function redo(): void {
        if (future.length === 0)
            return;
        history = history.concat([snapshot()]);
        restore(future[future.length - 1]);
        future = future.slice(0, -1);
    }
    function restore(list: var): void {
        undoing = true;
        Config.widgets.items = list;
        undoing = false;
        selected = "";
        picked = [];
    }
    // In edit mode: the widget whose toolbar is shown (last clicked or added).
    property string selected: ""
    // While dragging into a magnet slot: the widget it would attach to, and
    // the dragged one (the group is previewed as joined).
    property string attachHint: ""
    property string attachSideHint: ""
    property string attachChild: ""

    // Widget types. Add one: an entry here + a <Name>Widget.qml in widgets/
    // + a case in widgets/WidgetFrame.qml. `attach`: the type can attach to
    // other widgets: "music" (only to a Music widget) or "any".
    readonly property var types: [
        { type: "clock", name: "Clock", icon: "schedule", w: 320, h: 150, attach: "any",
          styles: [{ id: "classic", name: "Classic" }, { id: "light", name: "Light" }, { id: "minimal", name: "Minimal" }, { id: "date", name: "Date" },
                   { id: "stacked", name: "Stacked", w: 200, h: 200 }, { id: "split", name: "Split", w: 300, h: 140 }] },
        { type: "roundclock", name: "Round clock", icon: "nest_clock_farsight_analog", w: 220, h: 220, attach: "any",
          styles: [{ id: "classic", name: "Classic" }, { id: "minimal", name: "Minimal" }, { id: "numbers", name: "Numbers" }, { id: "dots", name: "Dots" }] },
        { type: "music", name: "Music", icon: "music_note", w: 360, h: 120, attach: "any",
          // `vis`: the built-in visualizer modes this style offers (item.vis).
          styles: [{ id: "card", name: "Card", w: 400, h: 136, vis: ["off", "ring", "glow", "bars", "wave", "mirror"] },
                   { id: "disc", name: "Disc", w: 440, h: 156, vis: ["off", "ring", "glow", "bars", "wave"] },
                   { id: "cover", name: "Cover", w: 236, h: 324, vis: ["off", "glow", "bars", "wave", "mirror"] },
                   { id: "minimal", name: "Minimal", w: 320, h: 84, vis: ["off", "bars", "wave"] }] },
        { type: "weather", name: "Weather", icon: "partly_cloudy_day", w: 300, h: 130, attach: "any",
          styles: [{ id: "card", name: "Card" }, { id: "forecast", name: "Forecast", w: 380, h: 170 },
                   { id: "hourly", name: "Hourly", w: 380, h: 130 }, { id: "minimal", name: "Minimal", w: 240, h: 64 },
                   { id: "big", name: "Big", w: 240, h: 170 }] },
        { type: "visualizer", name: "Visualizer", icon: "graphic_eq", w: 360, h: 130, attach: "music",
          styles: [{ id: "bars", name: "Bars" }, { id: "mirror", name: "Mirror" }, { id: "wave", name: "Wave" },
                   // alone: not while attached (a second album art next to
                   // the player's; the player has its own ring for that).
                   { id: "peaks", name: "Peaks" }, { id: "circle", name: "Circle", w: 240, h: 240, alone: true }] },
        { type: "eq", name: "Equalizer", icon: "tune", w: 380, h: 230, attach: "music" },
        { type: "lyrics", name: "Lyrics", icon: "lyrics", w: 360, h: 200, attach: "music",
          styles: [{ id: "scroll", name: "Scroll" }, { id: "focus", name: "Focus", w: 380, h: 120 },
                   { id: "karaoke", name: "Karaoke", w: 400, h: 132 },
                   { id: "minimal", name: "Minimal", w: 380, h: 56 }] },
        { type: "stats", name: "System", icon: "monitoring", w: 300, h: 132, attach: "any",
          styles: [{ id: "bars", name: "Bars" }, { id: "rings", name: "Rings", w: 300, h: 140 },
                   { id: "compact", name: "Compact", w: 360, h: 52 }, { id: "graph", name: "Graph", w: 320, h: 150 }] },
    ]

    // (JsonAdapter hands a `var` list over as a Qt list, not a JS array.)
    readonly property var items: {
        const l = Config.ready ? Config.widgets.items : null;
        return l && typeof l === "object" && l.length !== undefined
            ? Array.from(l).map(migrate).filter(i => i && i.id && typeType(i.type)) : [];
    }

    // Older names: the sound-wave widget was called "equalizer" before the
    // real equalizer existed.
    function migrate(i: var): var {
        return i && i.type === "equalizer" ? Object.assign({}, i, { type: "visualizer" }) : i;
    }

    function typeType(type: string): var {
        return types.find(t => t.type === type) ?? null;
    }

    function itemsOn(monitor: string): var {
        return items.filter(i => i.monitor === monitor);
    }

    function byId(id: string): var {
        return items.find(i => i.id === id) ?? null;
    }

    // New widget of `type`, centred in `area` ({ x, y, w, h } relative to
    // the monitor) on monitor `monitor`.
    function countOf(type: string): int {
        return items.filter(i => i.type === type).length;
    }

    function add(type: string, monitor: string, area: var): void {
        const t = typeType(type);
        if (!t || countOf(type) >= maxPerType)
            return;
        const item = {
            id: Date.now().toString(36) + Math.floor(Math.random() * 1e4).toString(36),
            type, monitor,
            x: Math.round(area.x + (area.w - t.w) / 2),
            y: Math.round(area.y + (area.h - t.h) / 2),
            scale: 1, opacity: 1
        };
        save(items.concat([item]));
        selected = item.id;
    }

    // The item's style id (valid for its type; else the type's first).
    // Styles marked `alone` fall back to the first while attached.
    function styleOf(item: var): string {
        const styles = stylesFor(item);
        return styles.find(s => s.id === item?.style)?.id ?? styles[0]?.id ?? "";
    }
    function stylesFor(item: var): var {
        const styles = typeType(item?.type ?? "")?.styles ?? [];
        return item?.attachedTo ? styles.filter(s => !s.alone) : styles;
    }

    // Music: the built-in visualizer mode (one the style offers, else "off").
    readonly property var visNames: ({ off: "No visualizer", ring: "Ring", glow: "Glow", bars: "Bars", wave: "Wave", mirror: "Mirror" })
    function visModes(item: var): var {
        const st = (typeType(item?.type ?? "")?.styles ?? []).find(s => s.id === styleOf(item));
        return st?.vis ?? [];
    }
    function visOf(item: var): string {
        const m = visModes(item);
        return m.indexOf(item?.vis) !== -1 ? item.vis : "off";
    }
    function cycleVis(id: string): void {
        const item = byId(id);
        const m = visModes(item);
        if (m.length < 2)
            return;
        update(id, { vis: m[(m.indexOf(visOf(item)) + 1) % m.length] });
    }

    // Base size of an item ({ w, h }): its style's size if it has one, else
    // the type's. Music in Card/Disc style grows by the visualizer.
    function sizeOf(item: var): var {
        const t = typeType(item?.type ?? "");
        if (!t)
            return { w: 100, h: 100 };
        const st = (t.styles ?? []).find(s => s.id === styleOf(item));
        return { w: st?.w ?? t.w, h: st?.h ?? t.h };
    }

    // The music widget used to have a built-in visualizer (Settings >
    // Widgets). It is now a separate widget that attaches under it: turn the
    // old setting into one attached Visualizer per music widget, once.
    Connections {
        target: Config
        function onReadyChanged() { Qt.callLater(root.migrateVisualizer); }
    }
    Component.onCompleted: if (Config.ready) Qt.callLater(migrateVisualizer)
    function migrateVisualizer(): void {
        const old = Config.widgets.visualizer;
        if (!old || old === "off")
            return;
        const style = ["bars", "mirror", "wave"].indexOf(old) !== -1 ? old : "bars";
        let list = items.slice();
        for (const m of items.filter(i => i.type === "music")) {
            if (list.some(i => i.attachedTo === m.id) || list.filter(i => i.type === "visualizer").length >= maxPerType)
                continue;
            list.push({ id: Date.now().toString(36) + Math.floor(Math.random() * 1e4).toString(36) + m.id.slice(-3),
                        type: "visualizer", monitor: m.monitor, x: m.x, y: m.y, scale: 1, opacity: m.opacity ?? 1,
                        style, attachedTo: m.id });
        }
        save(list);
        Config.widgets.visualizer = "off";
    }

    // Next style for this widget (the toolbar's style button).
    function cycleStyle(id: string): void {
        const item = byId(id);
        const styles = stylesFor(item);
        if (styles.length < 2)
            return;
        const i = styles.findIndex(s => s.id === styleOf(item));
        update(id, { style: styles[(i + 1) % styles.length].id });
    }

    function update(id: string, changes: var): void {
        save(items.map(i => i.id === id ? Object.assign({}, i, changes) : i));
    }

    // The same changes for several widgets at once (one save, one undo step).
    function updateMany(ids: var, changes: var): void {
        save(items.map(i => ids.indexOf(i.id) !== -1 ? Object.assign({}, i, changes) : i));
    }

    // A widget and every widget joined to its group (attachedTo chains),
    // as ids.
    function groupOf(id: string): var {
        let top = byId(id);
        for (let n = 0; top?.attachedTo && byId(top.attachedTo) && n < 50; n++)
            top = byId(top.attachedTo);
        if (!top)
            return [];
        const out = [top.id];
        for (let k = 0; k < out.length; k++)
            for (const i of items)
                if (i.attachedTo === out[k] && out.indexOf(i.id) === -1)
                    out.push(i.id);
        return out;
    }

    // From the widget right-click menu (widgets/WidgetMenu.qml); the frames
    // do the work, as they know their neighbours on screen.
    signal menuRequested(string id, string screen, point at)
    signal detachRequested(string id)
    signal removeRequested(string id)

    function remove(id: string): void {
        save(items.filter(i => i.id !== id));
    }

    // Replaced as a whole so JsonAdapter notices and saves it.
    function save(list: var): void {
        const now = Date.now();
        if (!undoing && now - lastSave > 600)
            history = history.concat([snapshot()]).slice(-30);
        if (!undoing)
            future = [];
        lastSave = now;
        Config.widgets.items = list;
    }
}
