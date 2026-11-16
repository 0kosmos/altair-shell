// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Layouts
import Qt.labs.folderlistmodel
import Quickshell
import qs.components
import qs.core
import qs.services
import qs.theme

// Wallpaper picker, "grid" style: a centred panel with a grid of thumbnails.
// Used when Settings -> Wallpaper -> Picker is "Grid". SUPER+W.
//
//   hover / arrows         preview on the desktop (behind your windows)
//   click / Space          apply
//   Enter / double-click   apply and close
//   Esc / click outside    close (the preview is dropped)
AltairPanel {
    id: picker

    readonly property int columns: 4
    readonly property real ratio: 9 / 16

    name: "wallpaper"
    available: Config.wallpaper.picker === "grid"
    panelWidth: 960
    panelHeight: 620 + 84   // + the theme row (two lines here)
    topOffset: 0.14

    content: Component {
        FocusScope {
            id: root
            focus: true

            Component.onDestruction: Wallpapers.preview = ""

            property string pending: ""
            function previewSoon(path: string): void {
                pending = path;
                previewDelay.restart();
            }
            Timer {
                id: previewDelay
                interval: 120
                onTriggered: Wallpapers.preview = root.pending
            }

            function apply(index: int, close: bool): void {
                if (index < 0 || index >= files.count)
                    return;
                previewDelay.stop();
                Wallpapers.set(files.get(index, "filePath"));
                if (close)
                    ShellState.close();
            }

            FolderListModel {
                id: files
                folder: Wallpapers.url(Wallpapers.folder)
                nameFilters: filter.nameFilters
                caseSensitive: false
                showDirs: false
                sortField: FolderListModel.Name
            }

            // ---- Header --------------------------------------------------------
            RowLayout {
                id: header
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: Theme.space.m
                anchors.leftMargin: Theme.space.l
                height: 40
                spacing: Theme.space.s

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    StyledText {
                        text: "Wallpaper"
                        font.pixelSize: Theme.font.title
                        font.weight: Font.DemiBold
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: Wallpapers.pretty(Wallpapers.folder) + (files.count > 0 ? ` · ${files.count} file${files.count === 1 ? "" : "s"}` : "")
                        color: Theme.fgMuted
                        font.pixelSize: Theme.font.small
                    }
                }

                PickerFilter {
                    id: filter
                    onNameFiltersChanged: grid.currentIndex = -1
                }
                PillButton {
                    text: "Open folder"
                    // Ask the file manager directly (org.freedesktop.FileManager1,
                    // implemented by Dolphin, Nautilus, Thunar, ...). Plain xdg-open
                    // uses the default app for folders, which on some systems is a
                    // terminal (kitty registers itself for folders). Falls back to
                    // xdg-open if no file manager offers the interface.
                    onClicked: Quickshell.execDetached(["sh", "-c",
                        "mkdir -p \"$1\" && { busctl --user call org.freedesktop.FileManager1 /org/freedesktop/FileManager1 org.freedesktop.FileManager1 ShowFolders ass 1 \"$2\" '' >/dev/null 2>&1 || exec xdg-open \"$1\"; }",
                        "sh", Wallpapers.folder, Wallpapers.url(Wallpapers.folder)])
                }
                PillButton {
                    visible: Wallpapers.current !== ""
                    text: "Use Hyprland's"
                    onClicked: Wallpapers.set("")
                }
            }

            // Colour themes for the wallpaper (WallpaperTheme).
            ThemeRow {
                id: themes
                z: 5
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: Theme.space.l
            }

            // ---- Grid ------------------------------------------------------------
            GridView {
                id: grid

                anchors.top: header.bottom
                anchors.topMargin: Theme.space.m
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: themes.top
                anchors.margins: Theme.space.m

                focus: true
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: files
                cellWidth: Math.floor(width / picker.columns)
                cellHeight: Math.round(cellWidth * picker.ratio)
                currentIndex: -1

                onCurrentIndexChanged: if (currentIndex >= 0) root.previewSoon(files.get(currentIndex, "filePath"))
                // Typing searches (see PickerFilter); the rest is for the grid.
                Keys.onPressed: event => {
                    if ([Qt.Key_Left, Qt.Key_Right, Qt.Key_Up, Qt.Key_Down].indexOf(event.key) !== -1)
                        Qt.callLater(() => Sounds.slide(files.count > 1 ? grid.currentIndex / (files.count - 1) : 0.5));
                    if (filter.handleKey(event)) {
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Space) {
                        root.apply(currentIndex, false);
                        event.accepted = true;
                    }
                }
                Keys.onReturnPressed: root.apply(currentIndex, true)
                Keys.onEnterPressed: root.apply(currentIndex, true)

                delegate: Item {
                    id: cell
                    required property int index
                    required property string filePath
                    required property var fileModified
                    required property real fileSize

                    width: grid.cellWidth
                    height: grid.cellHeight

                    WallpaperThumb {
                        anchors.fill: parent
                        anchors.margins: Theme.space.xs + 1
                        filePath: cell.filePath
                        fileModified: cell.fileModified
                        fileSize: cell.fileSize
                        focused: cell.GridView.isCurrentItem && grid.activeFocus
                        onHovered: root.previewSoon(cell.filePath)
                        onClicked: root.apply(cell.index, false)
                        onDoubleClicked: root.apply(cell.index, true)
                    }
                }
            }

            // ---- Empty folder ----------------------------------------------------
            Column {
                anchors.centerIn: grid
                visible: files.status === FolderListModel.Ready && files.count === 0
                spacing: Theme.space.s

                Icon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    name: "wallpaper"
                    size: 44
                    color: Theme.fgDisabled
                }
                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: filter.query !== "" ? `Nothing matches "${filter.query}"`
                        : filter.kind === "live" ? "No live wallpapers (videos) in " + Wallpapers.pretty(Wallpapers.folder)
                        : filter.kind === "pictures" ? "No pictures in " + Wallpapers.pretty(Wallpapers.folder)
                        : "No images or videos in " + Wallpapers.pretty(Wallpapers.folder)
                    color: Theme.fgMuted
                }
                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Add JPG, PNG, WebP or MP4/WebM files there; they appear here right away."
                    color: Theme.fgDisabled
                    font.pixelSize: Theme.font.small
                }
            }
        }
    }
}
