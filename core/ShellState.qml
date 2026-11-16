// SPDX-License-Identifier: GPL-3.0-or-later
pragma Singleton

import QtQuick
import Quickshell

// Runtime-only state (never persisted). Persistent settings live in Config.
Singleton {
    id: root

    readonly property string version: "0.1.0"

    // Panels that can be toggled over IPC. Only one is open at a time;
    // opening another closes the current one.
    readonly property list<string> panels: ["launcher", "dashboard", "notifications", "wallpaper", "calendar", "alttab"]

    // Name of the open panel, or "" when none is open.
    property string openPanel: ""

    // Settings is a normal window, independent of the panels above (it stays
    // open while you use the launcher, for example). "settings" is accepted by
    // open/close/toggle too.
    property bool settingsOpen: false
    // Dragging the bar to another edge (bar/Bar.qml): the edge it would go
    // to ("" = not dragging) and the monitor; bar/BarMoveHint.qml shows it.
    property string barDragTarget: ""
    property string barDragScreen: ""

    // Open Settings on a page ("widgets", "dock", ...).
    signal settingsPageRequested(string page)
    function openSettings(page: string): void {
        settingsOpen = true;
        settingsPageRequested(page);
    }

    // Ask the desktop on a monitor to open its right-click menu at (x, y)
    // (IPC "desktop menu"). x/y < 0 = the screen's centre.
    signal desktopMenuRequested(string monitor, int x, int y)

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
