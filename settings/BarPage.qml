// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Layouts
import qs.components
import qs.core
import qs.theme

Page {
    title: "Bar"

    SettingRow {
        title: "Position"
        Segmented {
            options: [{ label: "Top", value: "top" }, { label: "Bottom", value: "bottom" }]
            current: Theme.barPosition
            onSelected: value => Config.appearance.barPosition = value
        }
    }

    Section { text: "Workspaces" }

    SettingRow {
        title: "Always show"
        description: "Number of workspace dots shown even when empty. Higher workspaces appear when in use."
        RowLayout {
            spacing: Theme.space.m
            Slider {
                implicitWidth: 160
                from: 1
                to: 10
                value: Config.bar.workspaces
                onMoved: value => Config.bar.workspaces = value
            }
            StyledText {
                Layout.preferredWidth: 24
                text: Config.bar.workspaces
                color: Theme.fgMuted
                font.pixelSize: Theme.font.small
                tabular: true
            }
        }
    }

    Section { text: "Clock" }

    SettingRow {
        title: "Show date"
        description: "The date next to the time. The format follows your system's locale."
        Toggle {
            checked: Config.bar.showDate
            onToggled: value => Config.bar.showDate = value
        }
    }
}
