// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Layouts
import qs.components
import qs.core
import qs.lock
import qs.services
import qs.theme

// Lock screen: when to lock, the password field's typing animation (with a
// live preview), what the lock screen shows, and how to get back in if it
// ever breaks.
Page {
    id: page
    title: "Lock & power"

    SettingRow {
        title: "Lock now"
        description: "Also SUPER + L, or loginctl lock-session from a terminal."
        PillButton {
            text: "Lock"
            onClicked: Locker.lock()
        }
    }

    Section { text: "When" }

    SettingRow {
        title: "Lock when idle"
        description: "Videos and games that keep the screen awake also stop this."
        Segmented {
            options: [{ label: "Never", value: 0 }, { label: "5 min", value: 5 }, { label: "10 min", value: 10 },
                      { label: "15 min", value: 15 }, { label: "30 min", value: 30 }]
            current: Config.lock.idleMinutes
            onSelected: value => Config.lock.idleMinutes = value
        }
    }
    SettingRow {
        title: "Screen off"
        description: "Turns the screen off while locked and untouched. Any key or the mouse turns it back on."
        Segmented {
            options: [{ label: "Never", value: 0 }, { label: "30 s", value: 30 }, { label: "1 min", value: 60 },
                      { label: "5 min", value: 300 }]
            current: Config.lock.screenOffSeconds
            onSelected: value => Config.lock.screenOffSeconds = value
        }
    }
    SettingRow {
        title: "Lock before sleep"
        description: "Locks when the computer suspends or hibernates, so it wakes up locked."
        Toggle {
            checked: Config.lock.beforeSleep
            onToggled: value => Config.lock.beforeSleep = value
        }
    }

    Section { text: "Power menu" }

    SettingRow {
        title: "Countdown"
        description: "Log out, restart and shut down wait this long (SUPER + Escape opens the menu; Esc cancels)."
        Segmented {
            options: [{ label: "Off", value: 0 }, { label: "3 s", value: 3 }, { label: "5 s", value: 5 }]
            current: Config.lock.powerCountdown
            onSelected: value => Config.lock.powerCountdown = value
        }
    }

    Section { text: "Typing animation" }

    // Live preview: types a few characters, deletes some, gets one wrong.
    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 110
        radius: Theme.radius.m
        color: Theme.surfaceRaised
        border.width: 1
        border.color: Theme.border

        PasswordField {
            id: preview
            anchors.centerIn: parent
            width: 300
            height: 50
            live: false
            count: 0
            status: "idle"
            style: Config.lock.typing
        }

        Timer {
            id: demo
            // Steps: type 7, delete 2, type 3, "wrong", pause, again.
            property int step: 0
            readonly property var script: ["+", "+", "+", "+", "+", "+", "+", "-", "-", "+", "+", "+", "wrong", "", "", "", ""]
            interval: 190
            repeat: true
            running: page.visible && Theme.animations
            onTriggered: {
                const s = script[step];
                if (s === "+") {
                    if (preview.status !== "idle")
                        preview.status = "idle";
                    preview.count++;
                } else if (s === "-") {
                    preview.count--;
                } else if (s === "wrong") {
                    preview.status = "failed";
                    preview.count = 0;
                    preview.shakeNow();
                }
                step = (step + 1) % script.length;
            }
        }
        Component.onCompleted: if (!Theme.animations) preview.count = 6
    }

    Chips {
        Layout.bottomMargin: Theme.space.s
        options: [{ label: "Pop", value: "pop" }, { label: "Wave", value: "wave" }, { label: "Glow", value: "glow" },
                  { label: "Shapes", value: "shapes" }, { label: "Bars", value: "bars" }, { label: "Minimal", value: "minimal" }]
        current: Config.lock.typing
        onSelected: value => Config.lock.typing = value
    }

    Section { text: "Look" }

    SettingRow {
        title: "Blur the wallpaper"
        description: "Off shows the wallpaper sharp, just darkened."
        Toggle {
            checked: Config.lock.blurWallpaper
            onToggled: value => Config.lock.blurWallpaper = value
        }
    }
    SettingRow {
        title: "Music controls"
        description: "The song that's playing, with play/pause and skip."
        Toggle {
            checked: Config.lock.media
            onToggled: value => Config.lock.media = value
        }
    }

    Section { text: "If something goes wrong" }

    StyledText {
        Layout.fillWidth: true
        wrapMode: Text.Wrap
        color: Theme.fgMuted
        font.pixelSize: Theme.font.small
        textFormat: Text.StyledText
        text: "The lock uses your normal login password. After 3 wrong passwords in a row your system may lock the account for about 10 minutes (pam_faillock), on the lock screen and on the console.<br><br>"
            + "<b>SUPER + SHIFT + R</b> restarts Altair, also on the lock screen: it comes back locked.<br>"
            + "If that doesn't help: press <b>Ctrl + Alt + F3</b>, log in, run <b>loginctl unlock-sessions</b> (it may ask for your password), then go back with <b>Ctrl + Alt + F1</b> (or F2). The README has more under \"If the lock screen breaks\"."
    }
}
