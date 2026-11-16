// SPDX-License-Identifier: GPL-3.0-or-later
// Altair — entry point. Run with `qs -c altair` (or `qs -p <repo>` while developing).
import QtQuick
import Quickshell
import qs.alttab
import qs.bar
import qs.calendar
import qs.components
import qs.connections
import qs.core
import qs.display
import qs.dock
import qs.launcher
import qs.lock
import qs.notifications
import qs.osd
import qs.power
import qs.services
import qs.settings
import qs.theme
import qs.wallpaper
import qs.widgets

ShellRoot {
    Ipc {}
    Wallpaper {}
    Bar {}
    Dock {}
    Launcher {}
    NotificationPopups {}
    NotificationCenter {}
    CalendarPopup {}
    NetworkPanel {}
    BluetoothPanel {}
    BrightnessPanel {}
    AltTab {}
    DragOverlay {}
    WidgetLayer {}
    SettingsWindow {}
    WallpaperStrip {}
    WallpaperGrid {}
    LockScreen {}
    Osd {}
    PowerMenu {}

    // Singletons and Quickshell services start lazily, on first access.
    // Touch the ones we want ready at startup: Config (load/create the file),
    // Apps (scan .desktop files now, not when the launcher first opens) and
    // Notifs (register as the notification daemon right away).
    Component.onCompleted: {
        console.info("altair " + ShellState.version + " starting, config: " + Config.path);
        void Apps.list;
        void Notifs.count;
        void Hypr.blurStrength;   // apply the saved blur strength and border colours
        void WindowRules.rules;   // re-send per-app transparency rules
        void Placement.get;       // load saved positions now (Settings opens at its spot)
        void Equalizer.enabled;   // restore the music equalizer (and clean up a leftover)
        void WallpaperTheme.mode; // themes that follow the wallpaper
        void Sounds.enabled;      // listen for panel/volume/edit-mode events
        void Display.brightness;  // find monitors, re-apply the colour shader
        void Locker.locked;       // idle lock, logind, re-lock after a crash while locked
    }

    Connections {
        target: Config
        function onReadyChanged() {
            if (Config.ready)
                console.info("altair: config ready (valid=" + Config.valid + ", accent=" + Theme.accent + ")");
        }
    }
}
