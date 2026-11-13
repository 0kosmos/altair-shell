// SPDX-License-Identifier: GPL-3.0-or-later
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.core

// Installed applications (.desktop entries) and how often each was launched.
// Launch counts are kept in $XDG_STATE_HOME/altair/launcher.json and used by
// the launcher to rank frequently used apps first.
Singleton {
    id: root

    readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/altair"

    // Visible apps, alphabetical. DesktopEntries fills in asynchronously and
    // updates when apps are installed/removed; this binding follows along.
    readonly property var list: DesktopEntries.applications.values
        .filter(a => !a.noDisplay)
        .sort((a, b) => a.name.localeCompare(b.name))

    // { "<desktop id>": <launch count> }
    readonly property var launches: usage.launches

    // Terminal for apps with Terminal=true (execute() ignores that flag).
    readonly property string terminal: Config.apps.terminal || Quickshell.env("TERMINAL") || "kitty"

    function launch(entry): void {
        let argv = Array.from(entry.command);
        if (entry.runInTerminal)
            argv = [terminal, "-e", ...argv];
        Hypr.exec(argv, entry.workingDirectory);

        // Assign a new object: mutating the old one wouldn't notify bindings.
        const next = Object.assign({}, usage.launches);
        next[entry.id] = (next[entry.id] ?? 0) + 1;
        usage.launches = next;
    }

    FileView {
        path: root.stateDir + "/launcher.json"
        onAdapterUpdated: writeAdapter()
        // A missing file is normal on first run; it is created on first launch.
        printErrors: false

        JsonAdapter {
            id: usage
            property var launches: ({})
        }
    }
}
