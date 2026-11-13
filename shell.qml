// SPDX-License-Identifier: GPL-3.0-or-later
// Altair — entry point. Run with `qs -c altair` (or `qs -p <repo>` while developing).
import QtQuick
import Quickshell
import qs.bar
import qs.core
import qs.launcher
import qs.notifications
import qs.services
import qs.theme

ShellRoot {
    Ipc {}
    Bar {}
    Launcher {}
    NotificationPopups {}
    NotificationCenter {}

    // Singletons and Quickshell services start lazily, on first access.
    // Touch the ones we want ready at startup: Config (load/create the file),
    // Apps (scan .desktop files now, not when the launcher first opens) and
    // Notifs (register as the notification daemon right away).
    Component.onCompleted: {
        console.info("altair " + ShellState.version + " starting, config: " + Config.path);
        void Apps.list;
        void Notifs.count;
    }

    Connections {
        target: Config
        function onReadyChanged() {
            if (Config.ready)
                console.info("altair: config ready (valid=" + Config.valid + ", accent=" + Theme.accent + ")");
        }
    }
}
