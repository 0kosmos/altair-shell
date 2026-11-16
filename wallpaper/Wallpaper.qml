// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.core
import qs.services
import qs.theme

// The wallpaper, drawn by Altair on every screen. Two layers per screen:
//
//   background layer  the current wallpaper: the image, or a still frame of a
//                     video (the live video plays on top of it in its own
//                     process, see video/shell.qml)
//   bottom layer      only while the picker previews another wallpaper:
//                     above the live video, below all windows
//
// No wallpaper set = the background window is transparent (Hyprland's own
// background shows through) and only exists for the desktop's right-click
// menu; with that menu off too, there is no window at all.
// Memory: images are decoded at screen size (sourceSize), never at their
// original size, so a 5K image costs the same as a 1080p one (~8 MB).
Scope {
    Variants {
        model: Quickshell.screens

        Scope {
            id: perScreen
            required property var modelData

            // ---- Current wallpaper --------------------------------------------
            PanelWindow {
                id: bgWin
                screen: perScreen.modelData
                visible: Wallpapers.current !== "" || Config.desktop.menu

                WlrLayershell.namespace: "altair-background"
                WlrLayershell.layer: WlrLayer.Background
                exclusionMode: ExclusionMode.Ignore
                anchors {
                    top: true
                    bottom: true
                    left: true
                    right: true
                }
                color: Wallpapers.current !== "" ? "#000000" : "transparent"

                CrossfadeImage {
                    anchors.fill: parent
                    visible: Wallpapers.current !== ""
                    path: Wallpapers.stillFor(Wallpapers.current)
                    duration: 600
                }

                // Reads wallpaper colours for auto themes (one screen is enough).
                Loader {
                    active: perScreen.modelData === Quickshell.screens[0]
                    sourceComponent: PaletteExtractor {}
                }

                // Right-click on the empty desktop: the desktop menu.
                MouseArea {
                    anchors.fill: parent
                    enabled: Config.desktop.menu
                    acceptedButtons: Qt.RightButton
                    onClicked: mouse => {
                        menuLoader.at = Qt.point(mouse.x, mouse.y);
                        menuLoader.active = false;
                        menuLoader.active = true;
                    }
                }
                Connections {
                    target: ShellState
                    function onDesktopMenuRequested(monitor, x, y) {
                        if (monitor !== perScreen.modelData.name || !Config.desktop.menu)
                            return;
                        menuLoader.at = Qt.point(x < 0 ? bgWin.width / 2 : x, y < 0 ? bgWin.height / 2 : y);
                        menuLoader.active = false;
                        menuLoader.active = true;
                    }
                }
                LazyLoader {
                    id: menuLoader
                    property point at
                    DesktopMenu {
                        anchorWindow: bgWin
                        at: menuLoader.at
                        onDismissed: menuLoader.active = false
                    }
                }
            }

            // ---- Hover preview from the picker ----------------------------------
            // Stays mapped a moment after the preview ends, to fade out.
            PanelWindow {
                id: previewWin
                screen: perScreen.modelData

                property bool active: Wallpapers.preview !== "" && Wallpapers.preview !== Wallpapers.current
                property bool lingering: false
                visible: active || lingering
                onActiveChanged: if (!active) lingering = true

                // The picture to preview; the last one is kept while fading out.
                readonly property string target: active ? Wallpapers.stillFor(Wallpapers.preview) : ""
                property string shown: ""
                onTargetChanged: if (target) shown = target

                WlrLayershell.namespace: "altair-wallpaper-preview"
                WlrLayershell.layer: WlrLayer.Bottom
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
                exclusionMode: ExclusionMode.Ignore
                anchors {
                    top: true
                    bottom: true
                    left: true
                    right: true
                }
                color: "transparent"
                // Never take clicks: it's only a picture.
                mask: Region {}

                CrossfadeImage {
                    id: previewImage
                    anchors.fill: parent
                    opacity: previewWin.active ? 1 : 0
                    path: previewWin.shown
                    duration: 250

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.anim.normal
                            onRunningChanged: if (!running && !previewWin.active) previewWin.lingering = false
                        }
                    }
                }
            }
        }
    }
}
