// SPDX-License-Identifier: GPL-3.0-or-later
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.core

// Desktop widgets: the placed items (stored in config.json, widgets.items),
// the available types, and edit mode. Drawn by widgets/WidgetLayer.qml.
//
// An item: { id, type, monitor, x, y, scale, opacity, style }
//   style    one of the type's `styles` ids (missing = the first)
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

    // Widget types. Add one: an entry here + a <Name>Widget.qml in widgets/
    // + a case in widgets/WidgetFrame.qml.
    readonly property var types: [
        { type: "clock", name: "Clock", icon: "schedule", w: 320, h: 150,
          styles: [{ id: "classic", name: "Classic" }, { id: "light", name: "Light" }, { id: "minimal", name: "Minimal" }, { id: "date", name: "Date" }] },
        { type: "roundclock", name: "Round clock", icon: "nest_clock_farsight_analog", w: 220, h: 220,
          styles: [{ id: "classic", name: "Classic" }, { id: "minimal", name: "Minimal" }, { id: "numbers", name: "Numbers" }, { id: "dots", name: "Dots" }] },
        { type: "music", name: "Music", icon: "music_note", w: 360, h: 120,
          styles: [{ id: "card", name: "Card" }, { id: "disc", name: "Disc", w: 400, h: 150 },
                   { id: "cover", name: "Cover", w: 230, h: 300 }, { id: "minimal", name: "Minimal", w: 320, h: 84 }] },
        { type: "stats", name: "System", icon: "monitoring", w: 300, h: 132,
          styles: [{ id: "bars", name: "Bars" }, { id: "rings", name: "Rings", w: 300, h: 140 },
                   { id: "compact", name: "Compact", w: 360, h: 52 }] },
    ]

    // (JsonAdapter hands a `var` list over as a Qt list, not a JS array.)
    readonly property var items: {
        const l = Config.ready ? Config.widgets.items : null;
        return l && typeof l === "object" && l.length !== undefined
            ? Array.from(l).filter(i => i && i.id && typeType(i.type)) : [];
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
    readonly property int visualizerHeight: 44
    function sizeOf(item: var): var {
        const t = typeType(item?.type ?? "");
        if (!t)
            return { w: 100, h: 100 };
        const st = (t.styles ?? []).find(s => s.id === styleOf(item));
        let w = st?.w ?? t.w, h = st?.h ?? t.h;
        if (t.type === "music" && Config.widgets.visualizer !== "off" && (st?.id === "card" || st?.id === "disc"))
            h += visualizerHeight;
        return { w, h };
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
