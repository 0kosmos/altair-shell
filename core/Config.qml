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

    function reload(): void {
        file.reload();
    }

    FileView {
        id: file

        path: root.path
        watchChanges: true
        onFileChanged: reload()

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
                property string accent: "#7aa2f7"      // #RRGGBB or #AARRGGBB
                property string barPosition: "top"     // "top" | "bottom"
                property string fontFamily: "Inter"
                property string iconFontFamily: "Material Symbols Rounded"
            }

            property JsonObject effects: JsonObject {
                property bool animations: true
                property bool blur: true
                property bool liquidGlass: false
            }

            property JsonObject performance: JsonObject {
                // One switch that disables animations, blur and shaders.
                property bool lowPower: false
            }
        }
    }
}
