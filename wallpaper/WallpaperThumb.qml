// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.components
import qs.services
import qs.theme

// One wallpaper thumbnail, used by the strip and the grid picker.
// Shows the cached thumbnail (made on first use), a "live" badge for videos,
// a ring + check on the current wallpaper, and a subtle ring when focused.
// Emits hovered/clicked/doubleClicked; the picker decides what they do.
Item {
    id: thumb

    required property string filePath
    required property var fileModified
    required property real fileSize
    property bool focused: false
    property int radius: Theme.radius.m

    signal hovered()
    signal clicked()
    signal doubleClicked()

    readonly property bool selected: filePath === Wallpapers.current
    readonly property bool video: Wallpapers.isVideo(filePath)
    readonly property bool hovering: mouse.containsMouse
    readonly property string cached: Wallpapers.thumbFor(filePath, fileModified.getTime(), fileSize)
    // Let Qt decode the original (at thumbnail size) when no tool could make
    // a thumbnail. Not possible for videos: they keep the placeholder.
    readonly property bool direct: !video && (!Wallpapers.vipsAvailable || Wallpapers.failed[filePath] === true)
    property bool requested: false

    Rectangle {
        id: frame
        anchors.fill: parent
        radius: thumb.radius
        color: Theme.surfaceRaised
        scale: mouse.pressed ? 0.97 : thumb.hovering || thumb.focused ? 1.04 : 1
        Behavior on scale {
            NumberAnimation { duration: Theme.anim.normal; easing.type: Theme.anim.easingSlide }
        }

        Icon {
            anchors.centerIn: parent
            visible: image.status !== Image.Ready
            name: thumb.video ? "movie" : "image"
            size: 28
            color: Theme.fgDisabled
        }

        ClippingRectangle {
            anchors.fill: parent
            radius: parent.radius
            color: "transparent"

            Image {
                id: image
                anchors.fill: parent
                source: thumb.direct ? Wallpapers.url(thumb.filePath) : Wallpapers.url(thumb.cached)
                sourceSize: Qt.size(384, 216)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: false
                opacity: status === Image.Ready ? 1 : 0
                Behavior on opacity {
                    NumberAnimation { duration: Theme.anim.normal }
                }
                // No cached thumbnail yet: have one made. (Qt logs a "Cannot
                // open" warning for this first miss; harmless.)
                onStatusChanged: {
                    if (status === Image.Error && !thumb.direct && !thumb.requested) {
                        thumb.requested = true;
                        Wallpapers.request(thumb.filePath, thumb.cached);
                    }
                }
            }
        }

        // "Live" badge on videos.
        Rectangle {
            visible: thumb.video
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.margins: Theme.space.s
            width: liveRow.implicitWidth + Theme.space.s * 2
            height: 22
            radius: 11
            color: Qt.rgba(0, 0, 0, 0.55)

            Row {
                id: liveRow
                anchors.centerIn: parent
                spacing: 3
                Icon {
                    name: "play_arrow"
                    size: 14
                    fill: 1
                    color: "#ffffff"
                    anchors.verticalCenter: parent.verticalCenter
                }
                StyledText {
                    text: "Live"
                    color: "#ffffff"
                    font.pixelSize: Theme.font.small - 1
                    font.weight: Font.DemiBold
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        // Ring: accent for the current wallpaper, subtle for keyboard focus.
        Rectangle {
            anchors.fill: parent
            anchors.margins: -3
            radius: parent.radius + 3
            color: "transparent"
            border.width: thumb.selected ? 2 : thumb.focused ? 1.5 : 0
            border.color: thumb.selected ? Theme.accent : Theme.fgMuted
            Behavior on border.color {
                ColorAnimation { duration: Theme.anim.fast }
            }
        }

        // Check mark on the current wallpaper.
        Rectangle {
            visible: thumb.selected
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Theme.space.s
            width: 22
            height: 22
            radius: 11
            color: Theme.accent
            Icon {
                anchors.centerIn: parent
                name: "check"
                size: 16
                color: Theme.onAccent
            }
        }
    }

    Connections {
        target: Wallpapers
        function onThumbReady(t) {
            if (t === thumb.cached) {
                image.source = "";
                image.source = Wallpapers.url(thumb.cached);
            }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: thumb.hovered()
        onClicked: thumb.clicked()
        onDoubleClicked: thumb.doubleClicked()
    }
}
