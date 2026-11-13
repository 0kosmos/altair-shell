pragma Singleton

import QtQuick
import Quickshell

// Runtime-only state (never persisted). Persistent settings live in Config.
Singleton {
    id: root

    readonly property string version: "0.1.0-dev"

    // Panels that can be toggled over IPC. Only one is open at a time;
    // opening another closes the current one.
    readonly property list<string> panels: ["launcher", "settings", "dashboard", "notifications"]

    // Name of the open panel, or "" when none is open.
    property string openPanel: ""

    function isPanel(name: string): bool {
        return panels.indexOf(name) !== -1;
    }

    function open(name: string): bool {
        if (!isPanel(name)) {
            console.warn("altair: unknown panel '" + name + "'. Known: " + panels.join(", "));
            return false;
        }
        openPanel = name;
        return true;
    }

    function close(): void {
        openPanel = "";
    }

    function toggle(name: string): bool {
        if (openPanel === name) {
            close();
            return true;
        }
        return open(name);
    }
}
