// SPDX-License-Identifier: GPL-3.0-or-later
// Altair — live (video) wallpaper player.
//
// Runs as its OWN small Quickshell process, started by the main shell only
// while a video wallpaper is set (services/Wallpapers.qml). Video decoding
// costs a few hundred MB of memory; keeping it out of the main shell means that
// memory exists only while a live wallpaper is in use, and a decoder crash
// can't take the bar down.
//
// Settings come from environment variables; changes arrive over IPC:
//   qs ipc --pid <pid> call video pause | play | setSpeed 1.5 | setFill crop
// It exits by itself if the main shell (ALTAIR_PARENT_PID) goes away.
import QtQuick
import QtMultimedia
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
    id: root

    readonly property string file: Quickshell.env("ALTAIR_VIDEO") ?? ""
    property real speed: Number(Quickshell.env("ALTAIR_VIDEO_SPEED") ?? "1") || 1
    property string fill: Quickshell.env("ALTAIR_VIDEO_FILL") ?? "crop"
    property bool paused: Quickshell.env("ALTAIR_VIDEO_PAUSED") === "1"
    readonly property string parentPid: Quickshell.env("ALTAIR_PARENT_PID") ?? ""

    // A single decoder (each extra one would cost the same memory and CPU again).
    MediaPlayer {
        id: player
        source: root.file ? "file://" + root.file.split("/").map(encodeURIComponent).join("/") : ""
        loops: MediaPlayer.Infinite
        playbackRate: root.speed
        videoOutput: output
        // No AudioOutput: live wallpapers are always silent.
        onErrorOccurred: (error, message) => console.warn("altair-video: " + message)
        Component.onCompleted: root.paused ? pause() : play()
    }

    IpcHandler {
        target: "video"
        function pause(): void {
            root.paused = true;
            player.pause();
        }
        function play(): void {
            root.paused = false;
            player.play();
        }
        function setSpeed(value: real): void {
            root.speed = Math.max(0.25, Math.min(2, value));
        }
        function setFill(value: string): void {
            root.fill = value;
        }
    }

    // NOTE: one MediaPlayer can feed one VideoOutput, so the video plays on the
    // first screen; other screens keep the still frame drawn by the main shell.
    PanelWindow {
        screen: Quickshell.screens[0]

        WlrLayershell.namespace: "altair-live-wallpaper"
        WlrLayershell.layer: WlrLayer.Background
        exclusionMode: ExclusionMode.Ignore
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        // Transparent until the first frame: the main shell's still frame of
        // this video shows through, so starting looks seamless.
        color: "transparent"
        // Clicks go through to the main shell's background (desktop menu).
        mask: Region {}

        VideoOutput {
            id: output
            anchors.fill: parent
            fillMode: root.fill === "fit" ? VideoOutput.PreserveAspectFit : VideoOutput.PreserveAspectCrop
            endOfStreamPolicy: VideoOutput.KeepLastFrame
            opacity: 0
            readonly property bool showing: player.hasVideo && player.position > 0
            onShowingChanged: if (showing) opacity = 1
            Behavior on opacity {
                NumberAnimation { duration: 400 }
            }
        }
    }

    // Exit with the main shell (e.g. if it crashed), checked every 5 s.
    FileView {
        id: parentAlive
        path: root.parentPid ? "/proc/" + root.parentPid + "/stat" : ""
        printErrors: false
        onLoadFailed: Qt.exit(0)
    }
    Timer {
        interval: 5000
        running: root.parentPid !== ""
        repeat: true
        onTriggered: parentAlive.reload()
    }
}
