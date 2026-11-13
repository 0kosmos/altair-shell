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

    SettingRow {
        title: "Calendar on click"
        description: "Click the clock for a month calendar. Arrows or the mouse wheel change the month; click the month name to go back to today."
        Toggle {
            checked: Config.bar.clockPopup
            onToggled: value => Config.bar.clockPopup = value
        }
    }

    SettingRow {
        title: "Week numbers"
        description: "ISO week numbers in the calendar."
        enabled: Config.bar.clockPopup
        opacity: enabled ? 1 : 0.5
        Toggle {
            checked: Config.bar.weekNumbers
            onToggled: value => Config.bar.weekNumbers = value
        }
    }

    SettingRow {
        title: "Round clock in calendar"
        description: "An analogue clock next to the calendar."
        enabled: Config.bar.clockPopup
        opacity: enabled ? 1 : 0.5
        Toggle {
            checked: Config.bar.analogClock
            onToggled: value => Config.bar.analogClock = value
        }
    }

    SettingRow {
        title: "Seconds hand"
        description: "Ticks once a second, only while the calendar is open."
        enabled: Config.bar.clockPopup && Config.bar.analogClock
        opacity: enabled ? 1 : 0.5
        Toggle {
            checked: Config.bar.clockSeconds
            onToggled: value => Config.bar.clockSeconds = value
        }
    }
}
