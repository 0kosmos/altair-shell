// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Layouts
import qs.components
import qs.core
import qs.services
import qs.theme

// Search + kind filter for the wallpaper pickers (strip and grid):
// "All" | "Pictures" | "Live" (videos) and a search box. Typing anywhere in
// the picker searches (the picker forwards keys to handleKey), so arrows and
// Enter keep working on the wallpapers. Esc clears the search first.
// `nameFilters` goes straight into the picker's FolderListModel.
RowLayout {
    id: root

    property string query: ""
    // "all" | "pictures" | "live"; remembered in config.
    readonly property string kind: Config.ready && ["pictures", "live"].indexOf(Config.wallpaper.pickerKind) !== -1 ? Config.wallpaper.pickerKind : "all"

    // Glob characters in the query would change the pattern: drop them.
    readonly property string safeQuery: query.replace(/[*?\[\]\\]/g, "")
    readonly property var wantedFilters: {
        const exts = kind === "pictures" ? Wallpapers.imageFilters
            : kind === "live" ? Wallpapers.videoFilters
            : [...Wallpapers.imageFilters, ...Wallpapers.videoFilters];
        // "*.jpg" -> "*forest*.jpg"
        return exts.map(e => safeQuery ? "*" + safeQuery + "*" + e.slice(1) : e);
    }
    // Applied 150 ms after the last keystroke: re-listing the folder on
    // every key (while the previous listing still runs) left it empty.
    property var nameFilters: []
    Component.onCompleted: nameFilters = wantedFilters
    onWantedFiltersChanged: settle.restart()
    Timer {
        id: settle
        interval: 150
        onTriggered: root.nameFilters = root.wantedFilters
    }

    spacing: Theme.space.s

    // Returns true when the key was for the search.
    function handleKey(event: var): bool {
        const ctrl = event.modifiers & Qt.ControlModifier;
        if (event.key === Qt.Key_Escape && query !== "") {
            query = "";
            return true;
        }
        if (event.key === Qt.Key_Backspace && query !== "") {
            query = ctrl ? "" : query.slice(0, -1);
            return true;
        }
        // Space applies a wallpaper unless a search is being typed.
        if (event.key === Qt.Key_Space && query === "")
            return false;
        if (!ctrl && event.text.length > 0 && event.text.charCodeAt(0) >= 32 && event.text.charCodeAt(0) !== 127) {
            query += event.text;
            Sounds.typing();
            return true;
        }
        return false;
    }

    Segmented {
        options: [{ label: "All", value: "all" }, { label: "Pictures", value: "pictures" }, { label: "Live", value: "live" }]
        current: root.kind
        onSelected: value => Config.wallpaper.pickerKind = value
    }

    // The search box (shows what is typed; no text field of its own).
    Rectangle {
        Layout.preferredWidth: 220
        Layout.preferredHeight: 32
        radius: height / 2
        color: Theme.pressed
        border.width: 1
        border.color: root.query !== "" ? Qt.alpha(Theme.accent, 0.6) : Theme.border
        Behavior on border.color { ColorAnimation { duration: Theme.anim.fast } }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 6
            spacing: 6
            Icon {
                name: "search"
                size: 16
                color: Theme.fgMuted
            }
            StyledText {
                Layout.fillWidth: true
                text: root.query !== "" ? root.query : "Type to search"
                color: root.query !== "" ? Theme.fg : Theme.fgDisabled
                font.pixelSize: Theme.font.small + 1
                elide: Text.ElideLeft
            }
            // Caret while searching.
            Rectangle {
                visible: root.query !== ""
                implicitWidth: 2
                implicitHeight: 14
                radius: 1
                color: Theme.accent
            }
            IconButton {
                visible: root.query !== ""
                icon: "close"
                size: 22
                iconSize: 14
                onClicked: root.query = ""
            }
        }
    }
}
