// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import qs.components
import qs.core
import qs.services
import qs.theme

// Now playing (MPRIS): album art, title, artist, progress, previous /
// play-pause / next. Base size 360 x 120. With nothing playing: a compact
// "Nothing playing" state, or hidden (Settings > Widgets).
//
// MPRIS doesn't push the playback position, so it is asked for every 2 s,
// only while something is playing (the bar jumps; animating it would redraw
// the blurred widget layer every frame).
Item {
    id: root
    property string style: ""
    readonly property var player: Media.player
    readonly property bool idle: !Media.hasTrack
    // Read by WidgetFrame: hide the whole widget (outside edit mode).
    readonly property bool hidden: idle && Config.widgets.musicHideIdle

    Timer {
        interval: 2000
        repeat: true
        running: Media.playing && (root.player?.positionSupported ?? false)
        onTriggered: root.player.positionChanged()
    }

    // ---- Nothing playing -------------------------------------------------------
    RowLayout {
        anchors.centerIn: parent
        visible: root.idle
        spacing: Theme.space.s
        Icon {
            name: "music_note"
            size: 22
            color: Theme.fgMuted
        }
        StyledText {
            text: "Nothing playing"
            color: Theme.fgMuted
        }
    }

    // ---- Now playing ---------------------------------------------------------------
    RowLayout {
        anchors.fill: parent
        anchors.margins: 12
        visible: !root.idle
        spacing: 14

        ClippingRectangle {
            Layout.preferredWidth: 96
            Layout.preferredHeight: 96
            radius: Theme.radius.m
            color: Qt.alpha(Theme.fg, 0.06)

            Icon {
                anchors.centerIn: parent
                visible: art.status !== Image.Ready
                name: "album"
                size: 40
                color: Theme.fgDisabled
            }
            Image {
                id: art
                anchors.fill: parent
                source: root.player?.trackArtUrl ?? ""
                sourceSize: Qt.size(192, 192)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 2

            StyledText {
                Layout.fillWidth: true
                text: root.player?.trackTitle ?? ""
                font.weight: Font.DemiBold
            }
            StyledText {
                Layout.fillWidth: true
                text: root.player?.trackArtist ?? ""
                color: Theme.fgMuted
                font.pixelSize: Theme.font.small
            }

            Item { Layout.fillHeight: true }

            // Progress.
            Rectangle {
                Layout.fillWidth: true
                visible: (root.player?.lengthSupported ?? false) && (root.player?.length ?? 0) > 0
                implicitHeight: 4
                radius: 2
                color: Theme.pressed
                Rectangle {
                    width: parent.width * Math.max(0, Math.min(1, (root.player?.position ?? 0) / Math.max(1, root.player?.length ?? 1)))
                    height: parent.height
                    radius: 2
                    color: Theme.accent
                }
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: Theme.space.s
                IconButton {
                    icon: "skip_previous"
                    enabled: root.player?.canGoPrevious ?? false
                    opacity: enabled ? 1 : 0.4
                    onClicked: root.player.previous()
                }
                IconButton {
                    icon: Media.playing ? "pause" : "play_arrow"
                    size: 34
                    iconSize: 22
                    fill: 1
                    color: Theme.fg
                    enabled: root.player?.canTogglePlaying ?? false
                    onClicked: root.player.togglePlaying()
                }
                IconButton {
                    icon: "skip_next"
                    enabled: root.player?.canGoNext ?? false
                    opacity: enabled ? 1 : 0.4
                    onClicked: root.player.next()
                }
            }
        }
    }
}
