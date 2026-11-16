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

    SettingRow {
        title: "Recent apps"
        description: "Also show apps you used lately (or launch most often) that aren't pinned or open, after a thin line."
        enabled: Config.dock.enabled
        Toggle {
            checked: Config.dock.recentApps
            onToggled: value => Config.dock.recentApps = value
        }
    }

    SettingRow {
        title: "How many"
        enabled: Config.dock.enabled && Config.dock.recentApps
        RowLayout {
            spacing: Theme.space.m
            PillButton {
                text: "Forget"
                onClicked: DockApps.clearRecent()
            }
            Slider {
                implicitWidth: 120
                from: 1
                to: 6
                value: Config.dock.recentCount
                onMoved: value => Config.dock.recentCount = value
            }
            StyledText {
                Layout.preferredWidth: 16
                text: Config.dock.recentCount
                color: Theme.fgMuted
                font.pixelSize: Theme.font.small
                tabular: true
            }
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

    // ---- Add apps ------------------------------------------------------------
    SettingRow {
        title: "Add an app"
        description: "Type to search your installed apps, then click + to pin one."
        Rectangle {
            implicitWidth: 240
            implicitHeight: 32
            radius: Theme.radius.s
            color: Theme.pressed
            border.width: 1
            border.color: search.activeFocus ? Theme.accent : Theme.border
            Behavior on border.color { ColorAnimation { duration: Theme.anim.fast } }

            TextInput {
                id: search
                onTextEdited: Sounds.typing()   // user edits only
                anchors.fill: parent
                anchors.leftMargin: Theme.space.s
                anchors.rightMargin: Theme.space.s
                verticalAlignment: TextInput.AlignVCenter
                color: Theme.fg
                font.family: Theme.font.family
                font.pixelSize: Theme.font.small + 1
                clip: true
                selectByMouse: true

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !search.text && !search.activeFocus
                    text: "e.g. Firefox"
                    color: Theme.fgDisabled
                    font.pixelSize: Theme.font.small + 1
                }
            }
        }
    }

    // Matches (names first), at most 8, without already pinned apps.
    Repeater {
        model: {
            const q = search.text.trim().toLowerCase();
            if (!q)
                return [];
            const pinned = new Set(DockApps.pinned);
            const score = a => {
                const n = a.name.toLowerCase();
                return n.startsWith(q) ? 0 : n.includes(q) ? 1 : (a.genericName + " " + a.keywords.join(" ")).toLowerCase().includes(q) ? 2 : 9;
            };
            return Apps.list.filter(a => !pinned.has(a.id) && score(a) < 9)
                .sort((a, b) => score(a) - score(b))
                .slice(0, 8);
        }

        RowLayout {
            id: hit
            required property var modelData
            Layout.fillWidth: true
            spacing: Theme.space.m

            IconImage {
                implicitSize: 24
                source: Quickshell.iconPath(hit.modelData.icon, "application-x-executable")
            }
            StyledText {
                Layout.fillWidth: true
                text: hit.modelData.name
                elide: Text.ElideRight
            }
            IconButton {
                icon: "add"
                onClicked: DockApps.pin(hit.modelData.id, -1)
            }
        }
    }
}
