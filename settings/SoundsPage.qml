// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.components
import qs.core
import qs.services
import qs.theme

Page {
    id: page
    title: "Sounds"

    readonly property var builtIns: [{ label: "Glass", value: "glass" }, { label: "Soft", value: "soft" },
                                     { label: "Minimal", value: "minimal" }, { label: "Bubble", value: "bubble" },
                                     { label: "Wood", value: "wood" }, { label: "Pulse", value: "pulse" }]
    readonly property var styles: builtIns.concat([{ label: "File", value: "custom" }])

    SettingRow {
        title: "Sounds"
        description: Theme.lowPower ? "Off while low-power mode is on." : "All interface sounds, including notifications."
        Toggle {
            checked: Config.sounds.enabled
            onToggled: value => Config.sounds.enabled = value
        }
    }

    SettingRow {
        title: "Volume"
        description: "On top of the system volume."
        enabled: Config.sounds.enabled
        opacity: enabled ? 1 : 0.4

        RowLayout {
            spacing: Theme.space.m
            Slider {
                implicitWidth: 160
                from: 0
                to: 100
                stepSize: 5
                showTicks: false
                value: Math.round(Sounds.volume * 100)
                onMoved: value => Config.sounds.volume = value / 100
            }
            StyledText {
                Layout.preferredWidth: 40
                text: Math.round(Sounds.volume * 100) + "%"
                color: Theme.fgMuted
                font.pixelSize: Theme.font.small
                tabular: true
            }
        }
    }

    SettingRow {
        title: "Style for everything"
        description: "Sets every event below to the same sound family. Glass: light crystal chimes. Soft: warm, rounded tones. Minimal: tiny ticks and blips. Bubble: water drops. Wood: a soft marimba. Pulse: gentle synth blips."
        enabled: Config.sounds.enabled
        opacity: enabled ? 1 : 0.4
    }
    Chips {
        enabled: Config.sounds.enabled
        opacity: enabled ? 1 : 0.4
        Layout.bottomMargin: Theme.space.s
        options: page.builtIns
        // Lit only when every event uses the same style.
        current: Sounds.commonStyle()
        onSelected: value => {
            Sounds.setStyleAll(value);
            Sounds.preview("open");
        }
    }

    Section { text: "Events" }

    EventRow {
        event: "notification"
        title: "Notification"
        description: "A new notification (not while Do not disturb is on, except critical ones). Apps that bring their own sound play that instead."
    }
    EventRow {
        event: "open"
        title: "Open"
        description: "Opening the launcher, notifications, calendar, wallpaper picker or Settings."
    }
    EventRow {
        event: "close"
        title: "Close"
        description: "Closing them again."
    }
    EventRow {
        event: "click"
        title: "Click"
        description: "Buttons, menus and options like the ones on this page."
    }
    EventRow {
        event: "toggle"
        title: "Switch"
        description: "Switches like these: rising when turned on, falling when turned off."
    }
    EventRow {
        event: "slide"
        title: "Slider"
        description: "A soft tick while dragging a slider (volume above, icon size, wallpaper speed, colour, equalizer, music progress). The tick rises with the value."
    }
    EventRow {
        event: "typing"
        title: "Typing"
        description: "Typing in the launcher and search fields."
    }
    EventRow {
        event: "volume"
        title: "Volume"
        description: "Changing the output volume, from the bar, the keyboard or any app."
    }
    EventRow {
        event: "edit"
        title: "Edit mode"
        description: "Entering and leaving widget edit mode."
    }
    EventRow {
        event: "snap"
        title: "Snap"
        description: "A dragged widget or window catching a guide line."
    }

    // One event: on/off, which sound, a play button, and a file field for
    // "File".
    component EventRow: ColumnLayout {
        id: row

        required property string event
        property string title
        property string description

        readonly property bool on: event === "notification" ? Config.notifications.sound : Config.sounds.on[event] === true
        readonly property string style: Sounds.styleOf(event)
        readonly property string customPath: Config.sounds.custom && typeof Config.sounds.custom[event] === "string" ? Config.sounds.custom[event] : ""

        Layout.fillWidth: true
        spacing: Theme.space.s
        enabled: Config.sounds.enabled
        opacity: enabled ? 1 : 0.4

        SettingRow {
            title: row.title
            description: row.description

            RowLayout {
                spacing: Theme.space.s
                IconButton {
                    icon: "play_arrow"
                    iconSize: 22
                    fill: 1
                    onClicked: Sounds.preview(row.event)
                }
                Toggle {
                    checked: row.on
                    onToggled: value => {
                        if (row.event === "notification")
                            Config.notifications.sound = value;
                        else
                            Config.sounds.on[row.event] = value;
                    }
                }
            }
        }

        // Which sound (a row of its own: too many choices to fit beside the title).
        Chips {
            opacity: row.on ? 1 : 0.5
            options: row.event === "notification" ? [{ label: "System", value: "system" }].concat(page.styles) : page.styles
            current: row.style
            onSelected: value => {
                Config.sounds.style[row.event] = value;
                // Hear the choice right away (a file only once one is set).
                if (value !== "custom" || Sounds.customFile(row.event) !== "")
                    Sounds.preview(row.event);
            }
        }

        // Custom file: path + whether it can be used.
        RowLayout {
            Layout.fillWidth: true
            Layout.bottomMargin: Theme.space.s
            visible: row.style === "custom"
            spacing: Theme.space.m

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 32
                radius: Theme.radius.s
                color: Theme.pressed
                border.width: 1
                border.color: pathInput.activeFocus ? Theme.accent : Theme.border

                TextInput {
                    id: pathInput
                    anchors.fill: parent
                    anchors.leftMargin: Theme.space.s
                    anchors.rightMargin: Theme.space.s
                    verticalAlignment: TextInput.AlignVCenter
                    text: row.customPath
                    color: Theme.fg
                    font.family: Theme.font.family
                    font.pixelSize: Theme.font.small + 1
                    clip: true
                    selectByMouse: true
                    onAccepted: {
                        Sounds.setCustom(row.event, text.trim().replace(/^~(?=\/)/, Quickshell.env("HOME")));
                        focus = false;
                        if (Sounds.customFile(row.event) !== "")
                            Sounds.preview(row.event);
                    }

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: pathInput.text === "" && !pathInput.activeFocus
                        text: "/path/to/sound.ogg, then Enter"
                        color: Theme.fgDisabled
                        font.pixelSize: Theme.font.small + 1
                    }
                }
            }

            StyledText {
                Layout.preferredWidth: 220
                // Only reads the file while this row is visible.
                readonly property string status: row.customPath === "" ? "empty"
                    : !Sounds.isSoundPath(row.customPath.trim()) ? "type"
                    : check.loaded ? "ok" : check.failed ? "missing" : "checking"
                text: ({ empty: "Built-in Glass sound until a file is set.",
                         type: "Not a sound file (wav, ogg, opus, flac, mp3). Using Glass.",
                         missing: "File not found. Using Glass.",
                         ok: "Custom sound ready.",
                         checking: "" })[status]
                color: status === "ok" ? Theme.fgMuted : status === "empty" ? Theme.fgDisabled : Theme.accent
                font.pixelSize: Theme.font.small
                wrapMode: Text.Wrap

                FileView {
                    id: check
                    property bool loaded: false
                    property bool failed: false
                    path: row.style === "custom" && Sounds.isSoundPath(row.customPath.trim()) ? row.customPath.trim() : ""
                    printErrors: false
                    onPathChanged: { loaded = false; failed = false; }
                    onLoaded: loaded = true
                    onLoadFailed: failed = true
                }
            }
        }
    }
}
