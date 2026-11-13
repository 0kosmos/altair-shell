// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import Quickshell
import Quickshell.Wayland
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
// No wallpaper set = no windows at all, so Hyprland's own background shows.
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
                screen: perScreen.modelData
                visible: Wallpapers.current !== ""

                WlrLayershell.namespace: "altair-background"
                WlrLayershell.layer: WlrLayer.Background
                exclusionMode: ExclusionMode.Ignore
                anchors {
                    top: true
                    bottom: true
                    left: true
                    right: true
                }
                color: "#000000"

                CrossfadeImage {
                    anchors.fill: parent
                    path: Wallpapers.stillFor(Wallpapers.current)
                    duration: 600
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
