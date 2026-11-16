// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.components
import qs.core
import qs.services
import qs.theme

// What one monitor shows while locked: the wallpaper (blurred), the time,
// the password field and the music. Every monitor shows the same field;
// typing goes to whichever one has keyboard focus.
FocusScope {
    id: root

    property bool shown: false          // drives the open animation
    readonly property bool leaving: Locker.status === "success"
    Component.onCompleted: {
        shown = true;
        caps.check();
    }
    focus: true

    // ---- Background --------------------------------------------------------------------
    Rectangle {
        anchors.fill: parent
        color: "#000000"
    }
    Image {
        id: wall
        anchors.fill: parent
        source: Wallpapers.url(Wallpapers.stillFor(Wallpapers.current))
        fillMode: Image.PreserveAspectCrop
        sourceSize: Qt.size(root.width, root.height)
        asynchronous: false
        cache: false
        visible: !blurred.visible
    }
    MultiEffect {
        id: blurred
        anchors.fill: parent
        source: wall
        visible: Config.lock.blurWallpaper && !Theme.lowPower
        blurEnabled: true
        blurMax: 64
        blur: root.shown && !root.leaving ? 1 : 0
        autoPaddingEnabled: false
        Behavior on blur { NumberAnimation { duration: Theme.anim.slow; easing.type: Easing.OutCubic } }
    }
    // Darken so white text reads on any wallpaper.
    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: root.shown && !root.leaving ? 0.38 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.anim.slow } }
    }

    // ---- Content -----------------------------------------------------------------------
    Item {
        id: content
        anchors.fill: parent
        opacity: root.shown && !root.leaving ? 1 : 0
        scale: root.shown && !root.leaving ? 1 : 1.04
        Behavior on opacity { NumberAnimation { duration: Theme.anim.slow; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: Theme.anim.slow; easing.type: Easing.OutCubic } }

        SystemClock {
            id: clock
            precision: SystemClock.Minutes
        }

        ColumnLayout {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.verticalCenter
            anchors.bottomMargin: 24
            spacing: 0

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: Qt.locale().toString(clock.date, Qt.locale().timeFormat(Locale.ShortFormat))
                font.family: Theme.widgetFont || Theme.font.family
                font.pixelSize: Math.round(Math.min(root.height * 0.13, 132))
                font.weight: Font.Light
                tabular: true
                color: "#ffffff"
            }
            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: Qt.locale().toString(clock.date, "dddd d MMMM")
                font.family: Theme.widgetFont || Theme.font.family
                font.pixelSize: Theme.font.title + 2
                color: Qt.alpha("#ffffff", 0.82)
            }
        }

        ColumnLayout {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.verticalCenter
            anchors.topMargin: 36
            spacing: Theme.space.m
            width: 340

            // User.
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: Theme.space.s
                Rectangle {
                    implicitWidth: 30
                    implicitHeight: 30
                    radius: 15
                    color: Qt.alpha("#ffffff", 0.14)
                    Icon {
                        anchors.centerIn: parent
                        name: "person"
                        size: 18
                        color: "#ffffff"
                    }
                }
                StyledText {
                    text: Quickshell.env("USER") ?? ""
                    color: "#ffffff"
                    font.pixelSize: Theme.font.body + 1
                    font.weight: Font.Medium
                }
            }

            PasswordField {
                id: field
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 320
                Layout.preferredHeight: 54
                style: Config.lock.typing
                focus: true
            }

            // Messages: wrong password, faillock, Caps Lock, a broken PAM.
            StyledText {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 340
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                text: Locker.message !== "" ? Locker.message : caps.on ? "Caps Lock is on" : ""
                color: Locker.status === "failed" || Locker.status === "error" ? "#ffb4c0" : Qt.alpha("#ffffff", 0.75)
                font.pixelSize: Theme.font.small + 1
                opacity: text !== "" ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Theme.anim.fast } }
            }

            // The password check itself is broken: how to get back in. The
            // screen stays locked (no way in without a password).
            StyledText {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 360
                visible: Locker.broken
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                textFormat: Text.StyledText
                text: "Try <b>SUPER + SHIFT + R</b> (restarts Altair, stays locked), then your password again.<br>"
                    + "Still broken: <b>Ctrl + Alt + F3</b>, log in, run <b>loginctl unlock-sessions</b>, then <b>Ctrl + Alt + F2</b>."
                color: Qt.alpha("#ffffff", 0.8)
                font.pixelSize: Theme.font.small
            }
        }

        // ---- Music -------------------------------------------------------------------
        Item {
            id: music
            readonly property bool wanted: Config.lock.media && Media.hasTrack
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 48
            width: musicRow.implicitWidth + 28
            height: 64
            opacity: wanted ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: Theme.anim.normal } }

            Rectangle {
                anchors.fill: parent
                radius: Theme.radius.l
                color: Qt.alpha("#000000", 0.28)
                border.width: 1
                border.color: Qt.alpha("#ffffff", 0.10)
            }
            RowLayout {
                id: musicRow
                anchors.centerIn: parent
                spacing: Theme.space.m

                Rectangle {
                    implicitWidth: 42
                    implicitHeight: 42
                    radius: Math.round(10 * Theme.corners)
                    color: Qt.alpha("#ffffff", 0.1)
                    clip: true
                    Image {
                        anchors.fill: parent
                        source: Media.player?.trackArtUrl ?? ""
                        sourceSize: Qt.size(84, 84)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                    }
                }
                ColumnLayout {
                    spacing: 0
                    Layout.maximumWidth: 260
                    StyledText {
                        Layout.maximumWidth: 260
                        text: Media.player?.trackTitle ?? ""
                        color: "#ffffff"
                        font.weight: Font.Medium
                        elide: Text.ElideRight
                    }
                    StyledText {
                        Layout.maximumWidth: 260
                        text: Media.player?.trackArtist ?? ""
                        color: Qt.alpha("#ffffff", 0.7)
                        font.pixelSize: Theme.font.small
                        elide: Text.ElideRight
                    }
                }
                IconButton {
                    icon: "skip_previous"
                    color: "#ffffff"
                    enabled: Media.player?.canGoPrevious ?? false
                    onClicked: Media.player.previous()
                }
                IconButton {
                    icon: Media.playing ? "pause" : "play_arrow"
                    size: 34
                    iconSize: 24
                    color: "#ffffff"
                    onClicked: Media.player.togglePlaying()
                }
                IconButton {
                    icon: "skip_next"
                    color: "#ffffff"
                    enabled: Media.player?.canGoNext ?? false
                    onClicked: Media.player.next()
                }
            }
        }
    }

    // ---- Keys --------------------------------------------------------------------------
    // No text field: keys edit Locker.buffer directly, so nothing typed is
    // ever shown, selected or copied.
    Keys.onPressed: event => {
        const ctrl = event.modifiers & Qt.ControlModifier;
        const alt = event.modifiers & Qt.AltModifier;
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            Locker.submit();
        } else if (event.key === Qt.Key_Backspace) {
            if (ctrl)
                Locker.clear();
            else
                Locker.backspace();
        } else if (event.key === Qt.Key_Escape) {
            Locker.clear();
        } else if (event.text.length > 0 && event.text.charCodeAt(0) >= 32 && event.text.charCodeAt(0) !== 127
                   && (!ctrl || alt)) {   // Ctrl+key shortcuts are not text; AltGr (Ctrl+Alt) is
            Locker.type(event.text);
            Sounds.typing();
        } else {
            return;
        }
        caps.check();
        event.accepted = true;
    }

    // Caps Lock state from Hyprland, read after a key press (no polling).
    QtObject {
        id: caps
        property bool on: false
        function check(): void {
            if (!capsProc.running)
                capsProc.running = true;
        }
    }
    Process {
        id: capsProc
        command: ["hyprctl", "devices", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const kb = JSON.parse(text).keyboards ?? [];
                    caps.on = (kb.find(k => k.main) ?? kb[0])?.capsLock ?? false;
                } catch (e) {}
            }
        }
    }
}
