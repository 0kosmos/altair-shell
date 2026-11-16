// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.components
import qs.core
import qs.services
import qs.theme

Page {
    title: "Dock"

    SettingRow {
        title: "Show dock"
        description: "Pinned apps and open windows along a screen edge. Click to open or switch, right-click for more."
        Toggle {
            checked: Config.dock.enabled
            onToggled: value => Config.dock.enabled = value
        }
    }

    SettingRow {
        title: "Position"
        enabled: Config.dock.enabled
        Segmented {
            options: [{ label: "Bottom", value: "bottom" }, { label: "Left", value: "left" }, { label: "Right", value: "right" }]
            current: ["left", "right"].indexOf(Config.dock.position) !== -1 ? Config.dock.position : "bottom"
            onSelected: value => Config.dock.position = value
        }
    }

    SettingRow {
        title: "Icon size"
        enabled: Config.dock.enabled
        RowLayout {
            spacing: Theme.space.m
            Slider {
                implicitWidth: 160
                from: 32
                to: 64
                stepSize: 4
                value: Config.dock.iconSize
                onMoved: value => Config.dock.iconSize = value
            }
            StyledText {
                Layout.preferredWidth: 40
                text: Config.dock.iconSize + " px"
                color: Theme.fgMuted
                font.pixelSize: Theme.font.small
                tabular: true
            }
        }
    }

    SettingRow {
        title: "Auto-hide"
        description: "The dock slides away and comes back when the pointer touches the screen edge."
        enabled: Config.dock.enabled
        Toggle {
            checked: Config.dock.autoHide
            onToggled: value => Config.dock.autoHide = value
        }
    }

    SettingRow {
        title: "Keep windows clear of the dock"
        description: Config.dock.autoHide
            ? "Not used while auto-hide is on (windows would jump each time the dock shows)."
            : "Windows are tiled next to the dock instead of under it."
        enabled: Config.dock.enabled && !Config.dock.autoHide
        Toggle {
            checked: Config.dock.reserveSpace
            onToggled: value => Config.dock.reserveSpace = value
        }
    }

    SettingRow {
        title: "App grid button"
        description: "A button at the start of the dock that opens the launcher."
        enabled: Config.dock.enabled
        Toggle {
            checked: Config.dock.launcherButton
            onToggled: value => Config.dock.launcherButton = value
        }
    }

    Section { text: "Pinned apps" }

    StyledText {
        Layout.fillWidth: true
        text: DockApps.pinned.length === 0
            ? "Nothing pinned yet. Right-click an app in the dock and choose \"Pin to dock\", or drag it to the start of the dock."
            : "Drag icons in the dock to change the order."
        color: Theme.fgMuted
        font.pixelSize: Theme.font.small
        wrapMode: Text.Wrap
    }

    Repeater {
        model: DockApps.pinned

        RowLayout {
            id: row
            required property string modelData
            required property int index
            readonly property var entry: DesktopEntries.byId(modelData)

            Layout.fillWidth: true
            spacing: Theme.space.m

            IconImage {
                implicitSize: 24
                source: Quickshell.iconPath(row.entry?.icon ?? "", "application-x-executable")
            }
            StyledText {
                Layout.fillWidth: true
                text: row.entry?.name ?? row.modelData + " (not installed)"
                color: row.entry ? Theme.fg : Theme.fgMuted
                elide: Text.ElideRight
            }
            IconButton {
                icon: "keyboard_arrow_up"
                enabled: row.index > 0
                opacity: enabled ? 1 : 0.3
                onClicked: DockApps.move(row.modelData, row.index - 1)
            }
            IconButton {
                icon: "keyboard_arrow_down"
                enabled: row.index < DockApps.pinned.length - 1
                opacity: enabled ? 1 : 0.3
                onClicked: DockApps.move(row.modelData, row.index + 1)
            }
            IconButton {
                icon: "close"
                onClicked: DockApps.unpin(row.modelData)
            }
        }
    }
}
