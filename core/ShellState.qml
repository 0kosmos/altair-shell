// SPDX-License-Identifier: GPL-3.0-or-later
pragma Singleton

import QtQuick
import Quickshell

// Runtime-only state (never persisted). Persistent settings live in Config.
Singleton {
    id: root

    readonly property string version: "0.1.0-dev"

    // Panels that can be toggled over IPC. Only one is open at a time;
    // opening another closes the current one.
    readonly property list<string> panels: ["launcher", "dashboard", "notifications"]

    // Name of the open panel, or "" when none is open.
    property string openPanel: ""

    // Settings is a normal window, independent of the panels above (it stays
    // open while you use the launcher, for example). "settings" is accepted by
    // open/close/toggle too.
    property bool settingsOpen: false

    function isPanel(name: string): bool {
        return panels.indexOf(name) !== -1;
    }

    function open(name: string): bool {
        if (name === "settings") {
            settingsOpen = true;
            return true;
        }
        if (!isPanel(name)) {
            console.warn("altair: unknown panel '" + name + "'. Known: settings, " + panels.join(", "));
            return false;
        }
        openPanel = name;
        return true;
    }

    function close(): void {
        openPanel = "";
    }

    function toggle(name: string): bool {
        if (name === "settings") {
            settingsOpen = !settingsOpen;
            return true;
        }
        if (openPanel === name) {
            close();
            return true;
        }
        return open(name);
    }
}
