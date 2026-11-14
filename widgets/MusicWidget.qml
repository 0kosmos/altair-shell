// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import qs.components
import qs.core
import qs.services
import qs.theme

// Now playing (MPRIS). Styles (sizes in services/Widgets.qml):
//   card     album art, title, artist, progress, controls
//   disc     a vinyl record with the art as its label, spinning while playing
//   cover    big album art, title/artist and controls below
//   minimal  title, artist, small controls, a thin progress line
// Card and Disc show the visualizer below when it is on (Settings > Widgets).
// With nothing playing: a compact "Nothing playing", or hidden.
//
// Cost notes: MPRIS doesn't push the playback position, so it is asked for
// every 2 s, only while playing (the bar jumps; animating it would redraw the
// blurred widget layer every frame). The disc turns in 20 fps steps from a
// timer, not a Qt animation (that would run at the monitor's 165 Hz).
Item {
    id: root
    property string style: "card"
    property bool live: true        // false while covered by windows (WidgetFrame)
    readonly property var player: Media.player
    readonly property bool idle: !Media.hasTrack
    // Read by WidgetFrame: hide the whole widget (outside edit mode).
    readonly property bool hidden: idle && Config.widgets.musicHideIdle
    readonly property bool withVisualizer: Config.widgets.visualizer !== "off" && (style === "card" || style === "disc")
    readonly property real progress: Math.max(0, Math.min(1, (player?.position ?? 0) / Math.max(1, player?.length ?? 1)))
    readonly property bool hasLength: (player?.lengthSupported ?? false) && (player?.length ?? 0) > 0

    Timer {
        interval: 2000
        repeat: true
        running: root.live && Media.playing && (root.player?.positionSupported ?? false)
        onTriggered: root.player.positionChanged()
    }

    // ---- Shared pieces ---------------------------------------------------------------
    component Art: ClippingRectangle {
        property real r: Theme.radius.m
        radius: r
        color: Qt.alpha(Theme.fg, 0.06)
        Icon {
            anchors.centerIn: parent
            visible: img.status !== Image.Ready
            name: "album"
            size: Math.round(parent.width * 0.4)
            color: Theme.fgDisabled
        }
        Image {
            id: img
            anchors.fill: parent
            source: root.player?.trackArtUrl ?? ""
            sourceSize: Qt.size(256, 256)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
        }
    }

    component Titles: ColumnLayout {
        property int align: Qt.AlignLeft
        spacing: 2
        StyledText {
            Layout.fillWidth: true
            horizontalAlignment: parent.align === Qt.AlignHCenter ? Text.AlignHCenter : Text.AlignLeft
            text: root.player?.trackTitle ?? ""
            font.weight: Font.DemiBold
        }
        StyledText {
            Layout.fillWidth: true
            horizontalAlignment: parent.align === Qt.AlignHCenter ? Text.AlignHCenter : Text.AlignLeft
            text: root.player?.trackArtist ?? ""
            color: Theme.fgMuted
            font.pixelSize: Theme.font.small
        }
    }

    // Progress bar you can drag to seek (like Spotify): thicker with a knob on
    // hover; while dragging it shows where it will jump to, and seeks on
    // release. Only when the player supports seeking.
    component Progress: Item {
        id: prog
        property int thickness: 4
        readonly property bool canSeek: (root.player?.canSeek ?? false) && root.hasLength
        readonly property bool hot: seek.containsMouse || seek.pressed
        property real dragRatio: -1
        readonly property real shown: dragRatio >= 0 ? dragRatio : root.progress
        visible: root.hasLength
        implicitHeight: 14

        Rectangle {
            id: track
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: prog.hot && prog.canSeek ? prog.thickness + 2 : prog.thickness
            radius: height / 2
            color: Theme.pressed
            Behavior on height {
                NumberAnimation { duration: Theme.anim.fast; easing.type: Theme.anim.easing }
            }
            Rectangle {
                width: parent.width * prog.shown
                height: parent.height
                radius: height / 2
                color: Theme.accent
            }
        }
        Rectangle {
            visible: prog.canSeek
            width: 12
            height: 12
            radius: 6
            x: track.width * prog.shown - width / 2
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.fg
            scale: prog.hot ? 1 : 0
            Behavior on scale {
                NumberAnimation { duration: Theme.anim.fast; easing.type: Theme.anim.easing }
            }
        }

        MouseArea {
            id: seek
            anchors.fill: parent
            anchors.topMargin: -4
            anchors.bottomMargin: -4
            enabled: prog.canSeek
            hoverEnabled: true
            preventStealing: true
            cursorShape: Qt.PointingHandCursor
            function ratio(x: real): real {
                return Math.max(0, Math.min(1, x / width));
            }
            onPressed: mouse => prog.dragRatio = ratio(mouse.x)
            onPositionChanged: mouse => { if (pressed) prog.dragRatio = ratio(mouse.x); }
            onReleased: {
                if (root.player && prog.dragRatio >= 0) {
                    root.player.position = prog.dragRatio * root.player.length;
                    root.player.positionChanged();
                }
                prog.dragRatio = -1;
            }
            onCanceled: prog.dragRatio = -1
        }
    }

    component Controls: RowLayout {
        property int big: 34
        spacing: Theme.space.s
        IconButton {
            icon: "skip_previous"
            enabled: root.player?.canGoPrevious ?? false
            opacity: enabled ? 1 : 0.4
            onClicked: root.player.previous()
        }
        IconButton {
            icon: Media.playing ? "pause" : "play_arrow"
            size: parent.big
            iconSize: Math.round(parent.big * 0.65)
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

    // ---- Nothing playing -------------------------------------------------------------
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

    // ---- Now playing -----------------------------------------------------------------
    Loader {
        id: layout
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: parent.height - (root.withVisualizer ? Widgets.visualizerHeight : 0)
        visible: !root.idle
        sourceComponent: root.style === "disc" ? disc : root.style === "cover" ? cover
            : root.style === "minimal" ? minimal : card
    }

    Visualizer {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 14
        anchors.topMargin: 0
        height: Widgets.visualizerHeight - 18
        visible: root.withVisualizer && !root.idle
        active: visible && root.live
        style: Config.widgets.visualizer
    }

    Component {
        id: card
        RowLayout {
            spacing: 14
            Art {
                Layout.leftMargin: 12
                Layout.preferredWidth: 96
                Layout.preferredHeight: 96
            }
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.topMargin: 12
                Layout.bottomMargin: 10
                Layout.rightMargin: 12
                spacing: 2
                Titles { Layout.fillWidth: true }
                Item { Layout.fillHeight: true }
                Progress { Layout.fillWidth: true }
                Controls { Layout.alignment: Qt.AlignHCenter }
            }
        }
    }

    Component {
        id: disc
        RowLayout {
            spacing: 16

            // The record: grooves, the art as its label, a spindle hole. Turns
            // while playing; a tonearm lowers onto it when playback starts.
            Item {
                Layout.leftMargin: 10
                Layout.preferredWidth: 130
                Layout.preferredHeight: 130

                Item {
                    id: record
                    anchors.fill: parent

                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: "#141416"
                        border.width: 1
                        border.color: Qt.alpha("#ffffff", 0.08)
                    }
                    // Grooves.
                    Repeater {
                        model: 5
                        Rectangle {
                            required property int index
                            anchors.centerIn: parent
                            width: parent.width * (0.92 - index * 0.08)
                            height: width
                            radius: width / 2
                            color: "transparent"
                            border.width: 1
                            border.color: Qt.alpha("#ffffff", 0.05 + (index % 2) * 0.03)
                        }
                    }
                    // A soft sheen, so the turning is visible on the vinyl too.
                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width * 0.9
                        height: 2
                        color: Qt.alpha("#ffffff", 0.07)
                    }
                    Art {
                        anchors.centerIn: parent
                        width: parent.width * 0.42
                        height: width
                        r: width / 2
                    }
                    Rectangle {
                        anchors.centerIn: parent
                        width: 7
                        height: 7
                        radius: 3.5
                        color: Theme.base
                    }

                    // 20 fps steps of 3° (60°/s, a calm turn), only while playing.
                    Timer {
                        interval: 50
                        repeat: true
                        running: root.live && Media.playing && Config.widgets.discSpin && Theme.animations
                        onTriggered: record.rotation = (record.rotation + 3) % 360
                    }
                }

                // Tonearm: rests off the record, swings on when playing.
                Item {
                    x: parent.width - 18
                    y: 2
                    width: 8
                    height: 76
                    transformOrigin: Item.Top
                    rotation: Media.playing ? 24 : 6
                    Behavior on rotation {
                        NumberAnimation { duration: Theme.anim.slow; easing.type: Theme.anim.easing }
                    }
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 3
                        height: parent.height
                        radius: 1.5
                        color: Theme.fgMuted
                    }
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        width: 8
                        height: 14
                        radius: 2
                        color: Theme.fg
                    }
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: -4
                        width: 12
                        height: 12
                        radius: 6
                        color: Theme.fgMuted
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.topMargin: 18
                Layout.bottomMargin: 14
                Layout.rightMargin: 16
                spacing: 2
                Titles { Layout.fillWidth: true }
                Item { Layout.fillHeight: true }
                Progress { Layout.fillWidth: true }
                Controls { Layout.alignment: Qt.AlignHCenter }
            }
        }
    }

    Component {
        id: cover
        ColumnLayout {
            spacing: 8
            Art {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 12
                Layout.preferredWidth: 206
                Layout.preferredHeight: 190
                r: Theme.radius.m
            }
            Progress {
                Layout.fillWidth: true
                Layout.leftMargin: 12
                Layout.rightMargin: 12
            }
            Titles {
                Layout.fillWidth: true
                Layout.leftMargin: 12
                Layout.rightMargin: 12
                align: Qt.AlignHCenter
            }
            Controls { Layout.alignment: Qt.AlignHCenter }
            Item { Layout.fillHeight: true }
        }
    }

    Component {
        id: minimal
        Item {
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 10
                spacing: Theme.space.s
                Icon {
                    name: "music_note"
                    size: 20
                    color: Theme.accent
                }
                Titles { Layout.fillWidth: true }
                Controls { big: 30 }
            }
            Progress {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 10
                anchors.bottomMargin: 2
                thickness: 3
            }
        }
    }
}
