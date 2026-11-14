// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Layouts
import qs.components
import qs.core
import qs.theme

Page {
    title: "About"

    StyledText {
        Layout.fillWidth: true
        text: "Altair " + ShellState.version + " — a clean, fast desktop shell for Hyprland, built with Quickshell."
        wrapMode: Text.Wrap
    }

    Section { text: "Files" }
    Info { label: "Settings"; value: Config.path }
    Info { label: "Source"; value: "https://github.com/0kosmos/altair-shell" }
    Info { label: "Licence"; value: "GPL-3.0-or-later" }

    Section { text: "Keys" }
    Info { label: "SUPER + Space"; value: "App launcher" }
    Info { label: "SUPER + N"; value: "Notification centre" }
    Info { label: "SUPER + W"; value: "Wallpaper picker" }
    Info { label: "SUPER + ,"; value: "Settings" }
    Info { label: "SUPER + D"; value: "Edit desktop widgets" }
    Info { label: "ALT + Tab"; value: "Switch windows" }
    Info { label: "SUPER + CTRL + ← / →"; value: "Previous / next workspace" }
    Info { label: "SUPER + Tab"; value: "Last-used workspace" }
    Info { label: "SUPER + SHIFT + R"; value: "Restart Altair" }
    Info { label: "SUPER + SHIFT + Return"; value: "Terminal (works even if Altair is down)" }

    component Info: RowLayout {
        property string label
        property string value

        Layout.fillWidth: true
        spacing: Theme.space.l

        StyledText {
            Layout.preferredWidth: 170
            text: parent.label
            color: Theme.fgMuted
        }
        // Selectable, so paths and the URL can be copied.
        TextEdit {
            Layout.fillWidth: true
            text: parent.value
            readOnly: true
            selectByMouse: true
            wrapMode: Text.WrapAnywhere
            color: Theme.fg
            selectionColor: Theme.accent
            selectedTextColor: Theme.onAccent
            font.family: Theme.font.family
            font.pixelSize: Theme.font.body
        }
    }
}
