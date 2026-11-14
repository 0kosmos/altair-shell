// SPDX-License-Identifier: GPL-3.0-or-later
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.core

// Desktop widgets: the placed items (stored in config.json, widgets.items),
// the available types, and edit mode. Drawn by widgets/WidgetLayer.qml.
//
// An item: { id, type, monitor, x, y, scale, opacity, style, attachedTo }
//   style       one of the type's `styles` ids (missing = the first)
//   attachedTo  id of the widget it hangs under (Visualizer/Equalizer under
//               Music, see widgets/WidgetFrame.qml); its x/y/scale then only
//               matter once it is detached
//   x, y     position relative to the monitor's top-left (logical px)
//   scale    0.5 – 2.5 (size = the type's base size × scale)
//   opacity  0.2 – 1
Singleton {
    id: root

    // At most this many widgets of each type (all monitors together).
    readonly property int maxPerType: 3

    // Edit mode (runtime only): widgets above the windows, with handles.
    property bool editing: false
    onEditingChanged: selected = ""
    // In edit mode: the widget whose toolbar is shown (last clicked or added).
    property string selected: ""
    // While dragging into a magnet slot: the widget it would attach to, and
    // the dragged one (the group is previewed as joined).
    property string attachHint: ""
    property string attachChild: ""

    // Widget types. Add one: an entry here + a <Name>Widget.qml in widgets/
    // + a case in widgets/WidgetFrame.qml.
    readonly property var types: [
        { type: "clock", name: "Clock", icon: "schedule", w: 320, h: 150,
          styles: [{ id: "classic", name: "Classic" }, { id: "light", name: "Light" }, { id: "minimal", name: "Minimal" }, { id: "date", name: "Date" }] },
        { type: "roundclock", name: "Round clock", icon: "nest_clock_farsight_analog", w: 220, h: 220,
          styles: [{ id: "classic", name: "Classic" }, { id: "minimal", name: "Minimal" }, { id: "numbers", name: "Numbers" }, { id: "dots", name: "Dots" }] },
        { type: "music", name: "Music", icon: "music_note", w: 360, h: 120,
          styles: [{ id: "card", name: "Card", w: 380, h: 136 }, { id: "disc", name: "Disc", w: 420, h: 156 },
                   { id: "cover", name: "Cover", w: 236, h: 324 }, { id: "minimal", name: "Minimal", w: 320, h: 84 }] },
        { type: "visualizer", name: "Visualizer", icon: "graphic_eq", w: 360, h: 130,
          styles: [{ id: "bars", name: "Bars" }, { id: "mirror", name: "Mirror" }, { id: "wave", name: "Wave" },
                   { id: "peaks", name: "Peaks" }, { id: "circle", name: "Circle", w: 240, h: 240 }] },
        { type: "eq", name: "Equalizer", icon: "tune", w: 380, h: 230 },
        { type: "stats", name: "System", icon: "monitoring", w: 300, h: 132,
          styles: [{ id: "bars", name: "Bars" }, { id: "rings", name: "Rings", w: 300, h: 140 },
                   { id: "compact", name: "Compact", w: 360, h: 52 }] },
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
    function styleOf(item: var): string {
        const styles = typeType(item?.type ?? "")?.styles ?? [];
        return styles.find(s => s.id === item?.style)?.id ?? styles[0]?.id ?? "";
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
        const styles = typeType(item?.type ?? "")?.styles ?? [];
        if (styles.length < 2)
            return;
        const i = styles.findIndex(s => s.id === styleOf(item));
        update(id, { style: styles[(i + 1) % styles.length].id });
    }

    function update(id: string, changes: var): void {
        save(items.map(i => i.id === id ? Object.assign({}, i, changes) : i));
    }

    function remove(id: string): void {
        save(items.filter(i => i.id !== id));
    }

    // Replaced as a whole so JsonAdapter notices and saves it.
    function save(list: var): void {
        Config.widgets.items = list;
    }
}
