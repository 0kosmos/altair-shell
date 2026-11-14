// SPDX-License-Identifier: GPL-3.0-or-later
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Persistent user settings, stored in $XDG_CONFIG_HOME/altair/config.json.
//
// - Missing file   -> created with defaults.
// - Missing keys   -> defaults are used (the file is completed on the next save).
// - Broken JSON    -> defaults are used and the file is NEVER written, so a typo
//                     in a hand-edited config can't be silently wiped.
// - Edited on disk -> reloaded live (watchChanges).
//
// Components should not read Config directly for visuals; they go through Theme,
// which validates and derives values from it.
Singleton {
    id: root

    readonly property string dir: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/altair"
    readonly property string path: dir + "/config.json"

    // True after the first successful read (or after defaults were written).
    property bool ready: false
    // False while the file on disk contains invalid JSON; writes are blocked then.
    property bool valid: true

    readonly property alias appearance: adapter.appearance
    readonly property alias effects: adapter.effects
    readonly property alias performance: adapter.performance
    readonly property alias apps: adapter.apps
    readonly property alias notifications: adapter.notifications
    readonly property alias wallpaper: adapter.wallpaper
    readonly property alias windows: adapter.windows
    readonly property alias transparency: adapter.transparency
    readonly property alias bar: adapter.bar
    readonly property alias alttab: adapter.alttab
    readonly property alias widgets: adapter.widgets
    readonly property alias equalizer: adapter.equalizer

    function reload(): void {
        file.reload();
    }

    // Delays re-reading after an external change (see onFileChanged below).
    Timer {
        id: settle
        interval: 150
        onTriggered: file.reload()
    }

    FileView {
        id: file

        path: root.path
        watchChanges: true
        // Wait a moment before re-reading: some editors (and scripts) empty the
        // file first and then write it, and reading in between would see a
        // half-written file.
        onFileChanged: settle.restart()

        // Set while the default file is being created (see onLoadFailed / onSaved).
        property bool creating: false

        // Any change made from QML (e.g. the Settings app) is saved immediately.
        onAdapterUpdated: {
            if (root.valid)
                writeAdapter();
            else
                console.warn("altair: not saving settings, " + root.path + " contains invalid JSON. Fix or delete it.");
        }

        onLoaded: {
            // JsonAdapter silently keeps defaults on a parse error, so check ourselves.
            try {
                JSON.parse(text());
                root.valid = true;
            } catch (e) {
                root.valid = false;
                console.warn("altair: " + root.path + " is not valid JSON (" + e.message + "); using defaults.");
            }
            root.ready = true;
        }

        onLoadFailed: err => {
            if (err === FileViewError.FileNotFound) {
                console.info("altair: creating default config at " + root.path);
                root.valid = true;
                creating = true;
                // Deferred: writing from inside this handler races with the failed
                // read and the save's completion (onSaved) gets dropped.
                Qt.callLater(writeAdapter); // also creates the directory
            } else {
                root.valid = false;
                console.warn("altair: cannot read " + root.path + ": " + FileViewError.toString(err));
            }
            root.ready = true;
        }

        // The file watcher is only attached after a successful read, so a file we
        // just created wouldn't be watched. Re-read it once to attach the watcher.
        onSaved: {
            if (creating) {
                creating = false;
                reload();
            }
        }

        JsonAdapter {
            id: adapter

            property JsonObject appearance: JsonObject {
                property string theme: "dark"          // "dark" | "light"
                property string accent: "#7aa2f7"      // #RRGGBB, "mono" (adapts to the theme) or "palette"
                // "default", a built-in palette id (theme/palettes.js) or "custom"
                property string palette: "default"
                // Background, surface, muted, text, accent.
                property list<string> customPalette: ["#14151a", "#1f2128", "#3a3d47", "#e8e9ee", "#7aa2f7"]
                property string barPosition: "top"     // "top" | "bottom"
                // Hyprland window borders: "accent" (accent colour for the
                // focused window, soft grey for others), "hyprland" (colours from
                // hyprland.lua), "none" (no borders). Older configs: true/false.
                property var windowBorders: "accent"
                property string fontFamily: "Inter"
                property string iconFontFamily: "Material Symbols Rounded"
            }

            property JsonObject effects: JsonObject {
                property bool animations: true
                property bool blur: true
                // Hyprland's blur size/passes, 1–10. -1 = leave Hyprland's own
                // setting alone. NOTE: global — also affects window blur.
                property int blurStrength: -1
                property bool liquidGlass: false
            }

            property JsonObject apps: JsonObject {
                // Terminal for apps that need one. Empty = $TERMINAL, else kitty.
                property string terminal: ""
            }

            property JsonObject notifications: JsonObject {
                // Only critical notifications pop up; all still go to history.
                property bool doNotDisturb: false
                // Play a short sound for new notifications (via pw-play).
                property bool sound: false
            }

            property JsonObject wallpaper: JsonObject {
                // Image drawn by Altair. Empty = Altair draws no wallpaper and
                // Hyprland's own background shows.
                property string path: ""
                // Folder shown in the picker. Empty = ~/Pictures/Wallpapers.
                property string folder: ""
                property string fill: "crop"           // "crop" | "fit"
                // Picker: "strip" (scrollable row, docked to an edge) or "grid".
                property string picker: "strip"
                property string pickerPosition: "bottom"   // "bottom" | "center" | "top"
                // Live (video) wallpapers.
                property JsonObject live: JsonObject {
                    property bool enabled: true            // false = show a still frame
                    property real speed: 1.0               // 0.25 – 2
                    property string pauseWhen: "window"    // "window" | "fullscreen" | "never"
                }
            }

            property JsonObject windows: JsonObject {
                // Resize windows by dragging their edges (Hyprland resize_on_border).
                property bool resizeOnBorder: true
                // Windows glide when resized/dragged by hand, with a calm curve.
                property bool smoothResize: true
                // Workspace switching: "slide" | "slidevert" | "fade" | "off" |
                // "hyprland" (your own animation from hyprland.lua).
                property string workspaceAnim: "slide"
                property string workspaceSpeed: "calm"     // "calm" | "normal" | "fast"
                // Dragging the Settings window (and desktop widgets): snap to
                // screen edges/centre lines (hold Shift to move freely), dim
                // the rest of the screen by this much (0–0.6), optional grid
                // in px applied on drop (0 = off; 4, 8 or 16).
                property bool snapping: true
                property real dragDim: 0.45
                property int grid: 0
            }

            // Window transparency (services/WindowRules.qml). Applied as Hyprland
            // window rules at runtime; hyprland.lua is never edited.
            property JsonObject transparency: JsonObject {
                // Default opacity for all windows, 0.3–1. -1 = Hyprland's own
                // decoration.active_opacity / inactive_opacity.
                property real activeOpacity: -1
                property real inactiveOpacity: -1
                // Per-app rules, each:
                //   { name, match (regex on the window class), opacity,
                //     inactiveOpacity, blur (blur behind), enabled }
                // They replace the default above for matching windows.
                property var rules: []
            }

            property JsonObject widgets: JsonObject {
                // Placed desktop widgets (see services/Widgets.qml):
                //   { id, type, monitor, x, y, scale, opacity }
                property var items: []
                // Music widget: hide it while nothing is playing (else a
                // compact "Nothing playing").
                property bool musicHideIdle: false
                // System widget: GPU temperature via nvidia-smi (every 5 s,
                // only while the widget exists). NVIDIA only.
                property bool gpuTemp: false
                // Old built-in visualizer of the music widget ("off" | "bars" |
                // "mirror" | "wave"); now migrated to an attached Visualizer
                // widget (services/Widgets.qml) and set back to "off".
                property string visualizer: "off"
                // Visualizer widget frame rate (20 | 30 | 60). Only runs while playing.
                property int visualizerFps: 30
                // "auto" | "low" | "medium" | "high"
                property string visualizerSensitivity: "auto"
                // "snappy" | "balanced" | "smooth"
                property string visualizerSmoothing: "balanced"
                // Weather widget (Open-Meteo): the place (chosen in Settings,
                // only its coordinates are sent) and "c" | "f".
                property string weatherCity: ""
                property real weatherLat: 0
                property real weatherLon: 0
                property string weatherUnits: "c"
                // Music "Disc" style: the record spins while playing.
                property bool discSpin: true
            }

            // Music equalizer (services/Equalizer.qml): only the music
            // player's audio. preset: an id from Equalizer.presets; custom:
            // 6 gains in dB (60 Hz … 15 kHz), used by the "custom" preset.
            property JsonObject equalizer: JsonObject {
                property bool enabled: false
                property string preset: "flat"
                property var custom: [0, 0, 0, 0, 0, 0]
            }

            property JsonObject alttab: JsonObject {
                // Still previews of the windows (captured once per open);
                // false = app icons only.
                property bool previews: true
            }

            property JsonObject bar: JsonObject {
                property int workspaces: 5             // shown at least (1–10)
                property bool showDate: true           // date next to the time
                property bool clockPopup: true         // click the clock: calendar
                property bool weekNumbers: false       // ISO week numbers in the calendar
                property bool analogClock: true        // round clock in the calendar popup
                property bool clockSeconds: true       // its seconds hand (ticks once a second while open)
            }

            property JsonObject performance: JsonObject {
                // One switch that disables animations, blur and shaders.
                property bool lowPower: false
            }
        }
    }
}
