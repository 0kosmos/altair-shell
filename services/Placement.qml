// SPDX-License-Identifier: GPL-3.0-or-later
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Remembered positions of things the user placed (the Settings window now,
// desktop widgets later), per monitor, relative to that monitor's top-left.
// Stored in $XDG_STATE_HOME/altair/positions.json: it is state, not a setting.
//
//   { "<key>": { "<monitor name>": { "x": 120, "y": 80 } } }
Singleton {
    id: root

    function get(key: string, monitor: string): var {
        const p = store.positions?.[key]?.[monitor];
        return p && isFinite(p.x) && isFinite(p.y) ? p : null;
    }

    function set(key: string, monitor: string, pos: var): void {
        const all = Object.assign({}, store.positions);
        all[key] = Object.assign({}, all[key], { [monitor]: { x: Math.round(pos.x), y: Math.round(pos.y) } });
        store.positions = all;   // replaced as a whole so JsonAdapter saves it
    }

    function clear(key: string): void {
        const all = Object.assign({}, store.positions);
        delete all[key];
        store.positions = all;
    }

    FileView {
        path: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/altair/positions.json"
        printErrors: false
        // Tiny file, read synchronously: positions must be known the moment
        // something opens (e.g. Settings is placed before its window exists).
        blockLoading: true
        onAdapterUpdated: writeAdapter()

        JsonAdapter {
            id: store
            property var positions: ({})
        }
    }
}
