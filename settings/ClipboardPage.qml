// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Layouts
import qs.components
import qs.core
import qs.services
import qs.theme

// Clipboard history: on/off (needs cliphist), size, paste on choose, clear.
Page {
    id: page
    title: "Clipboard"

    StyledText {
        Layout.fillWidth: true
        visible: Clipboard.checked && !Clipboard.available
        wrapMode: Text.Wrap
        color: Theme.critical
        text: "Clipboard history needs cliphist: sudo pacman -S cliphist (then restart Altair)."
    }

    SettingRow {
        title: "Clipboard history"
        description: "Keeps what you copy (text and images) so you can paste it again: SUPER + SHIFT + V. Passwords copied from a password manager are never kept. Stays on this computer."
        Toggle {
            enabled: Clipboard.available
            checked: Config.clipboard.enabled
            onToggled: value => Config.clipboard.enabled = value
        }
    }
    SettingRow {
        title: "Keep"
        description: "Older entries are dropped."
        Segmented {
            options: [{ label: "100", value: 100 }, { label: "500", value: 500 }, { label: "1000", value: 1000 }]
            current: Config.clipboard.maxItems
            onSelected: value => Config.clipboard.maxItems = value
        }
    }
    SettingRow {
        title: "Paste when chosen"
        description: "Choosing an entry also pastes it into the window you were in (Ctrl+V, or Ctrl+Shift+V in terminals). Shift+Enter only copies."
        Toggle {
            checked: Config.clipboard.autoPaste
            onToggled: value => Config.clipboard.autoPaste = value
        }
    }
    SettingRow {
        title: "Clear history"
        description: "Removes every saved entry."
        PillButton {
            id: clearBtn
            property bool armed: false
            text: armed ? "Click again to clear" : "Clear"
            enabled: Clipboard.available
            onClicked: {
                if (armed) {
                    Clipboard.wipe();
                    armed = false;
                } else {
                    armed = true;
                    disarm.restart();
                }
            }
            Timer { id: disarm; interval: 3000; onTriggered: clearBtn.armed = false }
        }
    }
}
