// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.components
import qs.core
import qs.services
import qs.theme

Page {
    title: "Notifications"

    SettingRow {
        title: "Do not disturb"
        description: "Only critical notifications pop up. Everything still goes to the history."
        Toggle {
            checked: Config.notifications.doNotDisturb
            onToggled: value => Config.notifications.doNotDisturb = value
        }
    }

    SettingRow {
        title: "Sound"
        description: "A short sound for each new notification (not while Do not disturb is on, except for critical ones). Choose the sound under Sounds."
        Toggle {
            checked: Config.notifications.sound
            onToggled: value => Config.notifications.sound = value
        }
    }

    SettingRow {
        title: "Test"
        description: "Send a notification to see how it looks (and sounds)."
        PillButton {
            text: "Send test"
            onClicked: Quickshell.execDetached(["notify-send", "-a", "Altair", "Test notification", "This is what notifications look like."])
        }
    }

    SettingRow {
        title: "History"
        description: Notifs.count === 1 ? "1 notification kept." : Notifs.count + " notifications kept (up to " + Notifs.maxHistory + ")."
        PillButton {
            text: "Clear all"
            enabled: Notifs.count > 0
            opacity: enabled ? 1 : 0.4
            onClicked: Notifs.clearAll()
        }
    }
}
