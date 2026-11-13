// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import qs.components
import qs.core
import qs.services
import qs.theme

// Window transparency: a default for all windows plus per-app rules. Applied
// live as Hyprland window rules (services/WindowRules.qml); hyprland.lua is
// never edited.
Page {
    id: page
    title: "Transparency"

    // Slider positions: 30–100 %, and one step below that = "Hyprland's own".
    readonly property int minPct: 30

    StyledText {
        Layout.fillWidth: true
        visible: Theme.lowPower
        text: "Low-power mode is on: windows keep their opacity, but nothing is blurred behind them."
        color: Theme.accent
        font.pixelSize: Theme.font.small
        wrapMode: Text.Wrap
    }

    Section { text: "All windows" }

    Repeater {
        model: [
            { key: "activeOpacity", title: "Focused window", text: "Opacity of the window you are working in." },
            { key: "inactiveOpacity", title: "Other windows", text: "Opacity of all other windows." },
        ]

        SettingRow {
            required property var modelData
            readonly property real v: Config.transparency[modelData.key]

            title: modelData.title
            description: (v > 0 ? modelData.text : "Using your Hyprland setting.") + " Apps with their own rule below are not affected."

            RowLayout {
                spacing: Theme.space.m
                Slider {
                    implicitWidth: 160
                    from: page.minPct - 5
                    to: 100
                    stepSize: 5
                    showTicks: false
                    value: v > 0 ? Math.round(v * 100) : from
                    onMoved: value => Config.transparency[modelData.key] = value < page.minPct ? -1 : value / 100
                }
                StyledText {
                    Layout.preferredWidth: 64
                    text: v > 0 ? Math.round(v * 100) + " %" : "Hyprland"
                    color: Theme.fgMuted
                    font.pixelSize: Theme.font.small
                    tabular: true
                }
            }
        }
    }

    Section { text: "Apps" }

    StyledText {
        Layout.fillWidth: true
        visible: WindowRules.rules.length === 0
        text: "No app rules yet. Add a suggestion or one of your open windows below."
        color: Theme.fgMuted
        font.pixelSize: Theme.font.small
        wrapMode: Text.Wrap
    }

    // One card per rule. The model is the COUNT, so moving a slider (which
    // replaces the list) doesn't rebuild the cards mid-drag.
    Repeater {
        model: WindowRules.rules.length

        Rectangle {
            id: card
            required property int index
            readonly property var rule: WindowRules.rules[index] ?? {}
            readonly property bool on: rule.enabled !== false

            Layout.fillWidth: true
            implicitHeight: cardColumn.implicitHeight + Theme.space.m * 2
            radius: Theme.radius.m
            color: Theme.surfaceRaised
            border.width: 1
            border.color: Theme.border

            ColumnLayout {
                id: cardColumn
                anchors.fill: parent
                anchors.margins: Theme.space.m
                spacing: Theme.space.s

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.space.s

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        StyledText {
                            Layout.fillWidth: true
                            text: card.rule.name || card.rule.match
                            font.weight: Font.DemiBold
                        }
                        StyledText {
                            Layout.fillWidth: true
                            text: "Window class " + card.rule.match
                            color: Theme.fgDisabled
                            font.pixelSize: Theme.font.small
                        }
                    }
                    Toggle {
                        checked: card.on
                        onToggled: value => WindowRules.set(card.index, { enabled: value })
                    }
                    IconButton {
                        icon: "delete"
                        onClicked: WindowRules.remove(card.index)
                    }
                }

                Repeater {
                    model: [
                        { key: "opacity", label: "Focused" },
                        { key: "inactiveOpacity", label: "Unfocused" },
                    ]

                    RowLayout {
                        required property var modelData
                        readonly property int pct: Math.round(WindowRules.clamp(card.rule[modelData.key]) * 100)

                        Layout.fillWidth: true
                        enabled: card.on
                        opacity: enabled ? 1 : 0.5
                        spacing: Theme.space.m

                        StyledText {
                            Layout.preferredWidth: 90
                            text: modelData.label
                            color: Theme.fgMuted
                            font.pixelSize: Theme.font.small
                        }
                        Slider {
                            Layout.fillWidth: true
                            from: page.minPct
                            to: 100
                            stepSize: 5
                            showTicks: false
                            value: pct
                            onMoved: value => WindowRules.set(card.index, { [modelData.key]: value / 100 })
                        }
                        StyledText {
                            Layout.preferredWidth: 48
                            horizontalAlignment: Text.AlignRight
                            text: pct + " %"
                            color: Theme.fgMuted
                            font.pixelSize: Theme.font.small
                            tabular: true
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    enabled: card.on
                    opacity: enabled ? 1 : 0.5
                    StyledText {
                        Layout.fillWidth: true
                        text: Theme.lowPower ? "Blur behind (paused by low-power mode)" : "Blur behind"
                        color: Theme.fgMuted
                        font.pixelSize: Theme.font.small
                    }
                    Toggle {
                        checked: card.rule.blur !== false
                        onToggled: value => WindowRules.set(card.index, { blur: value })
                    }
                }
            }
        }
    }

    // ---- Adding rules --------------------------------------------------------
    Section { text: "Add an app" }

    SettingRow {
        id: suggestRow
        readonly property var available: WindowRules.suggestions.filter(s => !WindowRules.hasMatch(s.match))
        visible: available.length > 0
        title: "Suggestions"
        description: "Ready-made rules for common apps (they match the usual package and Flatpak names)."

        Flow {
            width: 300
            spacing: Theme.space.xs
            Repeater {
                model: suggestRow.available
                PillButton {
                    required property var modelData
                    text: "+ " + modelData.name
                    onClicked: WindowRules.add(modelData)
                }
            }
        }
    }

    SettingRow {
        id: openRow
        // Classes of the open windows that no rule covers yet (not Altair's own).
        readonly property var classes: {
            const seen = [];
            for (const t of Hyprland.toplevels.values) {
                const c = t.lastIpcObject?.class ?? "";
                if (c && c !== "org.quickshell" && seen.indexOf(c) === -1 && !WindowRules.covers(c))
                    seen.push(c);
            }
            return seen.sort();
        }
        visible: classes.length > 0
        title: "Open windows"
        description: "Add a rule for an app that is open right now."
        Component.onCompleted: Hyprland.refreshToplevels()

        Flow {
            width: 300
            spacing: Theme.space.xs
            Repeater {
                model: openRow.classes
                PillButton {
                    required property string modelData
                    text: "+ " + modelData
                    onClicked: WindowRules.addClass(modelData)
                }
            }
        }
    }

    SettingRow {
        title: "Window class"
        description: "Or type a window class (as shown by hyprctl clients) and press Enter."

        Rectangle {
            implicitWidth: 240
            implicitHeight: 32
            radius: Theme.radius.s
            color: Theme.pressed
            border.width: 1
            border.color: classInput.activeFocus ? Theme.accent : Theme.border

            TextInput {
                id: classInput
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
                    visible: !classInput.text && !classInput.activeFocus
                    text: "e.g. org.gnome.Nautilus"
                    color: Theme.fgDisabled
                    font.pixelSize: Theme.font.small + 1
                }

                onAccepted: {
                    WindowRules.addClass(text);
                    text = "";
                }
            }
        }
    }
}
