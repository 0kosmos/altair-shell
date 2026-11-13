// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Layouts
import Qt.labs.folderlistmodel
import Quickshell
import qs.components
import qs.core
import qs.services
import qs.theme

// Wallpaper picker, "strip" style: a compact carousel. The selected wallpaper
// is always large in the middle; neighbours shrink and fade toward the sides.
// Bottom, centre or top of the screen (Settings -> Wallpaper). SUPER+W.
//
//   arrows / Tab           move one wallpaper, wrapping around at the ends
//   wheel                  up = right, down = left (stops at the ends)
//   hover                  preview that wallpaper
//   click                  apply it (and bring it to the middle)
//   Enter / double-click   apply and close
//   Esc / click outside    close (the preview is dropped)
AltairPanel {
    id: strip

    readonly property int cardWidth: 240
    readonly property int cardHeight: 135
    readonly property int cardSpacing: 14
    // Room above/below the cards for the enlarged middle card and its ring.
    readonly property int cardPad: 12

    name: "wallpaper"
    available: Config.wallpaper.picker !== "grid"
    dock: Config.wallpaper.pickerPosition === "top" ? "top"
        : Config.wallpaper.pickerPosition === "center" ? "" : "bottom"
    fullWidth: false
    centerVertically: true
    // About five cards wide.
    panelWidth: cardWidth * 5 + cardSpacing * 4 + 48
    panelHeight: 46 + cardHeight + cardPad * 2 + 14

    content: Component {
        FocusScope {
            id: root
            focus: true

            // Leaving the picker drops the preview.
            Component.onDestruction: Wallpapers.preview = ""

            property string hoveredName: ""

            // Preview after a short pause, so sweeping across the row doesn't
            // load every picture on the way.
            property string pending: ""
            function previewSoon(path: string): void {
                pending = path;
                previewDelay.restart();
            }
            Timer {
                id: previewDelay
                interval: 140
                onTriggered: Wallpapers.preview = root.pending
            }

            function apply(index: int, close: bool): void {
                if (index < 0 || index >= files.count)
                    return;
                previewDelay.stop();
                list.currentIndex = index;
                Wallpapers.set(files.get(index, "filePath"));
                if (close)
                    ShellState.close();
            }

            FolderListModel {
                id: files
                folder: Wallpapers.url(Wallpapers.folder)
                nameFilters: [...Wallpapers.imageFilters, ...Wallpapers.videoFilters]
                caseSensitive: false
                showDirs: false
                sortField: FolderListModel.Name
            }

            // ---- Header ----------------------------------------------------------
            RowLayout {
                id: header
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.topMargin: Theme.space.m
                anchors.leftMargin: Theme.space.l
                anchors.rightMargin: Theme.space.m
                height: 28
                spacing: Theme.space.s

                StyledText {
                    text: "Wallpaper"
                    font.pixelSize: Theme.font.body + 1
                    font.weight: Font.DemiBold
                }
                StyledText {
                    Layout.fillWidth: true
                    text: {
                        const name = root.hoveredName || (list.currentItem ? list.currentItem.name : "");
                        return name ? "·  " + name : "·  " + Wallpapers.pretty(Wallpapers.folder);
                    }
                    color: Theme.fgMuted
                    font.pixelSize: Theme.font.small + 1
                }
                PillButton {
                    text: "Open folder"
                    // Ask the file manager directly (see WallpaperGrid.qml).
                    onClicked: Quickshell.execDetached(["sh", "-c",
                        "mkdir -p \"$1\" && { busctl --user call org.freedesktop.FileManager1 /org/freedesktop/FileManager1 org.freedesktop.FileManager1 ShowFolders ass 1 \"$2\" '' >/dev/null 2>&1 || exec xdg-open \"$1\"; }",
                        "sh", Wallpapers.folder, Wallpapers.url(Wallpapers.folder)])
                }
                PillButton {
                    visible: Wallpapers.current !== ""
                    text: "Use Hyprland's"
                    onClicked: Wallpapers.set("")
                }
                IconButton {
                    icon: "settings"
                    onClicked: {
                        ShellState.close();
                        ShellState.open("settings");
                    }
                }
            }

            // ---- Carousel ------------------------------------------------------------
            ListView {
                id: list

                anchors.top: header.bottom
                anchors.topMargin: Theme.space.s
                anchors.left: parent.left
                anchors.right: parent.right
                height: strip.cardHeight + strip.cardPad * 2

                orientation: ListView.Horizontal
                spacing: strip.cardSpacing
                // Empty room at both ends, so the first and last wallpapers
                // can also reach the middle.
                leftMargin: (width - strip.cardWidth) / 2
                rightMargin: (width - strip.cardWidth) / 2
                clip: true
                focus: true
                model: files
                boundsBehavior: Flickable.StopAtBounds

                // The current item always sits in the middle; moving glides.
                highlightRangeMode: ListView.StrictlyEnforceRange
                preferredHighlightBegin: (width - strip.cardWidth) / 2
                preferredHighlightEnd: (width + strip.cardWidth) / 2
                highlightMoveDuration: Theme.anim.slow
                highlightMoveVelocity: -1
                currentIndex: -1

                // Open on the current wallpaper, without animation. Done again
                // when the width changes: the centre is computed from it, and
                // it is still 0 the first time the files are listed.
                function centerOn(i: int): void {
                    highlightMoveDuration = 0;
                    currentIndex = i;
                    positionViewAtIndex(i, ListView.Center);
                    highlightMoveDuration = Qt.binding(() => Theme.anim.slow);
                }
                onCountChanged: {
                    if (currentIndex >= 0 || count === 0)
                        return;
                    let start = 0;
                    for (let i = 0; i < count; i++)
                        if (files.get(i, "filePath") === Wallpapers.current) {
                            start = i;
                            break;
                        }
                    Qt.callLater(centerOn, start);
                }
                onWidthChanged: if (currentIndex >= 0) Qt.callLater(centerOn, currentIndex)
                // The middle one is previewed (nothing happens for the current one).
                onCurrentIndexChanged: if (currentIndex >= 0 && count > 0) root.previewSoon(files.get(currentIndex, "filePath"))

                // wrap: past the last one, start again at the first (and back).
                function step(delta: int, wrap: bool): void {
                    root.hoveredName = "";
                    if (count === 0)
                        return;
                    const i = currentIndex + delta;
                    currentIndex = wrap ? (i % count + count) % count : Math.max(0, Math.min(count - 1, i));
                }

                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Right || event.key === Qt.Key_Tab)
                        step(1, true);
                    else if (event.key === Qt.Key_Left || event.key === Qt.Key_Backtab)
                        step(-1, true);
                    else if (event.key === Qt.Key_Home)
                        step(-count, false);
                    else if (event.key === Qt.Key_End)
                        step(count, false);
                    else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                        root.apply(currentIndex, true);
                    else if (event.key === Qt.Key_Space)
                        root.apply(currentIndex, false);
                    else
                        return;
                    event.accepted = true;
                }

                delegate: Item {
                    id: card
                    required property int index
                    required property string filePath
                    required property string fileName
                    required property var fileModified
                    required property real fileSize
                    readonly property string name: fileName.replace(/\.[^.]+$/, "")

                    width: strip.cardWidth
                    height: list.height

                    // 0 in the middle, 1 one card away, more further out —
                    // follows the scroll position every frame while gliding.
                    readonly property real distance: Math.abs(x - list.contentX - list.preferredHighlightBegin) / (strip.cardWidth + strip.cardSpacing)
                    readonly property real nearness: 1 - Math.min(1, distance)

                    WallpaperThumb {
                        anchors.centerIn: parent
                        width: strip.cardWidth
                        height: strip.cardHeight
                        // The middle card is full size, the others step back.
                        scale: 0.8 + 0.2 * card.nearness
                        opacity: 0.45 + 0.55 * card.nearness
                        filePath: card.filePath
                        fileModified: card.fileModified
                        fileSize: card.fileSize
                        focused: card.ListView.isCurrentItem
                        onHovered: {
                            root.hoveredName = card.name;
                            root.previewSoon(card.filePath);
                        }
                        onClicked: root.apply(card.index, false)
                        onDoubleClicked: root.apply(card.index, true)
                    }
                }

                // Empty folder.
                Column {
                    anchors.centerIn: parent
                    visible: files.status === FolderListModel.Ready && files.count === 0
                    spacing: Theme.space.xs
                    StyledText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "No images or videos in " + Wallpapers.pretty(Wallpapers.folder)
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

            // Wheel: one wallpaper per notch (touchpads accumulate). Up moves
            // right, down moves left; a horizontal swipe moves the way the
            // fingers go. A button-less MouseArea on top: it takes only wheel
            // events, so hover and clicks still reach the cards below. (A
            // WheelHandler inside the ListView never saw the events.)
            MouseArea {
                anchors.fill: list
                acceptedButtons: Qt.NoButton
                property int accum: 0
                onWheel: wheel => {
                    const d = Math.abs(wheel.angleDelta.x) > Math.abs(wheel.angleDelta.y) ? wheel.angleDelta.x : wheel.angleDelta.y;
                    accum += d;
                    while (Math.abs(accum) >= 120) {
                        const dir = accum > 0 ? 1 : -1;
                        accum -= dir * 120;
                        list.step(dir, false);
                    }
                }
            }
        }
    }
}
