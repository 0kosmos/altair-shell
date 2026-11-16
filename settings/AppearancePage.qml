// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import qs.components
import qs.core
import qs.theme

Page {
    id: page
    title: "Appearance"

    // Preset accents. "mono" is monochrome: near-white on dark, dark grey on light.
    readonly property var swatches: ["#7aa2f7", "#bb9af7", "#7dcfff", "#73daca", "#9ece6a", "#e0af68", "#ff9e64", "#f7768e", "mono"]

    SettingRow {
        title: "Theme"
        description: Theme.usingPalette ? "Set by the palette below. Choose \"Default\" to switch between dark and light." : ""
        enabled: !Theme.usingPalette
        opacity: enabled ? 1 : 0.4
        Segmented {
            options: [{ label: "Dark", value: "dark" }, { label: "Light", value: "light" }]
            current: Config.appearance.theme === "light" ? "light" : "dark"
            onSelected: value => Config.appearance.theme = value
        }
    }

    // ---- Palette -------------------------------------------------------------
    Section { text: "Palette" }

    StyledText {
        Layout.fillWidth: true
        text: "Five colours of one hue: background, surface, muted, text and accent. Applies to the bar, panels, Settings and (with accent borders) window borders."
        color: Theme.fgMuted
        font.pixelSize: Theme.font.small
        wrapMode: Text.Wrap
    }

    readonly property string paletteSetting: Config.appearance.palette
    // The preset that was active before switching to Custom (for "Copy from").
    property string lastPreset: ""
    Component.onCompleted: if (paletteSetting !== "custom") lastPreset = paletteSetting
    onPaletteSettingChanged: if (paletteSetting !== "custom") lastPreset = paletteSetting
    readonly property var paletteCards: [
        { id: "default", name: "Default", colors: ["#14151a", "#1f2128", "#3a3d47", "#e8e9ee", "#7aa2f7"] },
        ...Theme.palettes,
        { id: "custom", name: "Custom", colors: Config.appearance.customPalette }
    ]

    function choosePalette(id: string): void {
        if (id !== "custom" && id !== "default")
            Config.appearance.accent = "palette";
        else if (id === "default" && Config.appearance.accent === "palette")
            Config.appearance.accent = "#7aa2f7";
        else if (id === "custom")
            Config.appearance.accent = "palette";
        Config.appearance.palette = id;
    }

    Flow {
        Layout.fillWidth: true
        spacing: Theme.space.s

        Repeater {
            model: page.paletteCards

            PaletteCard {
                required property var modelData
                name: modelData.name
                colors: modelData.colors
                selected: page.paletteSetting === modelData.id
                custom: modelData.id === "custom"
                onClicked: page.choosePalette(modelData.id)
            }
        }
    }

    // Editor for the custom palette: pick a slot, then its colour.
    property int editingSlot: -1
    ColumnLayout {
        Layout.fillWidth: true
        visible: page.paletteSetting === "custom"
        spacing: Theme.space.m

        RowLayout {
            spacing: Theme.space.s
            Repeater {
                model: 5
                MouseArea {
                    id: slot
                    required property int index
                    readonly property color value: Config.appearance.customPalette[index] ?? "#000000"
                    implicitWidth: 92
                    implicitHeight: 64
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    scale: pressed ? Theme.anim.pressScale : 1
                    Behavior on scale {
                        NumberAnimation { duration: Theme.anim.fast; easing.type: Easing.OutBack; easing.overshoot: 2.5 }
                    }
                    onClicked: {
                        page.editingSlot = page.editingSlot === index ? -1 : index;
                        if (page.editingSlot >= 0)
                            slotPicker.load(value);
                    }

                    Rectangle {
                        anchors.top: parent.top
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 40
                        height: 40
                        radius: 20
                        color: slot.value
                        border.width: page.editingSlot === slot.index ? 3 : 1
                        border.color: page.editingSlot === slot.index ? Theme.fg : Theme.border
                        Icon {
                            anchors.centerIn: parent
                            visible: slot.containsMouse || page.editingSlot === slot.index
                            name: "colorize"
                            size: 15
                            color: Theme.contrast(slot.value, "#111216") > Theme.contrast(slot.value, "#ffffff") ? "#111216" : "#ffffff"
                        }
                    }
                    StyledText {
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Theme.paletteRoles[slot.index]
                        color: Theme.fgMuted
                        font.pixelSize: Theme.font.small
                    }
                }
            }

            Item { Layout.fillWidth: true }

            PillButton {
                readonly property var source: page.paletteCards.find(p => p.id === page.lastPreset)
                visible: source !== undefined && page.lastPreset !== ""
                text: "Copy from " + (source?.name ?? "")
                onClicked: {
                    Config.appearance.customPalette = source.colors.slice();
                    page.editingSlot = -1;
                }
            }
        }

        ColorPicker {
            id: slotPicker
            visible: page.editingSlot >= 0
            Layout.preferredWidth: 420

            // Live while dragging, throttled like the accent picker.
            property color pending
            onChanged: (value, final) => {
                pending = value;
                if (final) {
                    slotThrottle.stop();
                    page.setSlot(value);
                } else if (!slotThrottle.running) {
                    slotThrottle.start();
                }
            }
            Timer {
                id: slotThrottle
                interval: 90
                onTriggered: page.setSlot(slotPicker.pending)
            }
        }
    }

    function setSlot(c: color): void {
        if (editingSlot < 0)
            return;
        const next = Array.from(Config.appearance.customPalette);
        next[editingSlot] = slotPicker.hex(c);
        Config.appearance.customPalette = next;
    }

    // ---- Accent ----------------------------------------------------------------
    Section { text: "Accent colour" }

    readonly property string accentSetting: Config.appearance.accent.toLowerCase()
    // With a palette, its own accent is offered first.
    readonly property var shownSwatches: Theme.usingPalette ? ["palette", ...swatches] : swatches
    readonly property bool customAccent: shownSwatches.indexOf(accentSetting) === -1
    property bool pickerOpen: false

    Flow {
        Layout.fillWidth: true
        spacing: Theme.space.s

        Repeater {
            model: page.shownSwatches

            Swatch {
                required property string modelData
                fillColor: modelData === "mono" ? Theme.monoColor
                    : modelData === "palette" ? Theme.paletteColors[4] : modelData
                selected: page.accentSetting === modelData
                onClicked: Config.appearance.accent = modelData
            }
        }

        // Custom colour: shows the colour when it isn't one of the presets.
        // The pipette stays visible on top, so it's always findable.
        // Opens the picker below.
        Swatch {
            fillColor: page.customAccent ? Theme.chosenAccent : Theme.pressed
            selected: page.customAccent || page.pickerOpen
            onClicked: {
                if (!page.pickerOpen)
                    picker.load(Theme.chosenAccent);
                page.pickerOpen = !page.pickerOpen;
            }

            Icon {
                anchors.centerIn: parent
                name: "colorize"
                size: 15
                // Readable on any fill: dark or light, whichever contrasts more.
                color: !page.customAccent ? Theme.fgMuted
                    : Theme.contrast(Theme.chosenAccent, "#111216") > Theme.contrast(Theme.chosenAccent, "#ffffff") ? "#111216" : "#ffffff"
                opacity: page.customAccent ? 0.85 : 1
            }
        }
    }

    // The picker unfolds under the swatches.
    Item {
        Layout.fillWidth: true
        implicitHeight: page.pickerOpen ? picker.implicitHeight + Theme.space.s : 0
        clip: true
        opacity: page.pickerOpen ? 1 : 0

        Behavior on implicitHeight {
            NumberAnimation { duration: Theme.anim.normal; easing.type: Theme.anim.easingSlide }
        }
        Behavior on opacity {
            NumberAnimation { duration: Theme.anim.normal }
        }

        ColorPicker {
            id: picker
            width: Math.min(parent.width, 420)
            y: Theme.space.xs

            // Live while dragging, but at most every 90 ms: every accent change
            // re-colours the shell, rewrites the config file and (with accent
            // borders) updates Hyprland.
            property color pending
            onChanged: (value, final) => {
                pending = value;
                if (final) {
                    throttle.stop();
                    page.applyAccent(value);
                } else if (!throttle.running) {
                    throttle.start();
                }
            }
            Timer {
                id: throttle
                interval: 90
                onTriggered: page.applyAccent(picker.pending)
            }
        }
    }

    function applyAccent(c: color): void {
        Config.appearance.accent = picker.hex(c);
    }

    component Swatch: MouseArea {
        id: swatch
        property color fillColor
        property bool selected: false

        width: 32
        height: 32
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true
        scale: pressed ? Theme.anim.pressScale : 1
        Behavior on scale {
            NumberAnimation { duration: Theme.anim.fast; easing.type: Easing.OutBack; easing.overshoot: 2.5 }
        }

        // Ring around the selected colour.
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: "transparent"
            border.width: 2
            border.color: swatch.selected ? Theme.fg : swatch.containsMouse ? Theme.fgDisabled : "transparent"
            Behavior on border.color {
                ColorAnimation { duration: Theme.anim.fast }
            }
        }
        Rectangle {
            anchors.centerIn: parent
            width: 22
            height: 22
            radius: 11
            color: swatch.fillColor
            Behavior on color {
                ColorAnimation { duration: Theme.anim.fast }
            }
        }
    }

    // A palette preview: its five colours as stripes, and its name.
    component PaletteCard: MouseArea {
        id: card
        property string name
        property var colors: []
        property bool selected: false
        property bool custom: false

        width: 128
        height: 74
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        scale: pressed ? Theme.anim.pressScale : containsMouse ? 1.03 : 1
        Behavior on scale {
            NumberAnimation { duration: Theme.anim.fast; easing.type: Easing.OutBack; easing.overshoot: 2.5 }
        }

        Rectangle {
            anchors.fill: parent
            radius: Theme.radius.m
            color: Theme.surfaceRaised
            border.width: card.selected ? 2 : 1
            border.color: card.selected ? Theme.accent : card.containsMouse ? Theme.fgDisabled : Theme.border
            Behavior on border.color {
                ColorAnimation { duration: Theme.anim.fast }
            }
        }

        // Stripes, rounded as a group.
        ClippingRectangle {
            id: stripes
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 6
            height: 38
            radius: Theme.radius.s
            color: "transparent"
            Row {
                anchors.fill: parent
                Repeater {
                    model: card.colors
                    Rectangle {
                        required property string modelData
                        width: stripes.width / 5
                        height: stripes.height
                        color: modelData
                    }
                }
            }
        }

        RowLayout {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.leftMargin: 9
            anchors.rightMargin: 6
            anchors.bottomMargin: 6
            spacing: 2
            StyledText {
                Layout.fillWidth: true
                text: card.name
                font.pixelSize: Theme.font.small
                font.weight: card.selected ? Font.DemiBold : Font.Normal
            }
            Icon {
                visible: card.custom
                name: "edit"
                size: 13
                color: Theme.fgMuted
            }
            Icon {
                visible: card.selected
                name: "check"
                size: 14
                color: Theme.accent
            }
        }
    }

    Section { text: "Settings layout" }

    // Small pictures of each layout; click to switch (Settings rearranges live).
    Flow {
        Layout.fillWidth: true
        spacing: Theme.space.m
        Repeater {
            model: [{ id: "left", name: "Sidebar" }, { id: "right", name: "Sidebar right" }, { id: "rail", name: "Icon rail" },
                    { id: "top", name: "Tabs on top" }, { id: "bottom", name: "Tabs below" }]
            MouseArea {
                id: lay
                required property var modelData
                readonly property bool on: Theme.settingsLayout === modelData.id
                width: 120
                height: 96
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Config.appearance.settingsLayout = modelData.id
                scale: pressed ? Theme.anim.pressScale : 1
                Behavior on scale { NumberAnimation { duration: Theme.anim.fast; easing.type: Easing.OutBack } }

                Rectangle {
                    id: mini
                    width: parent.width
                    height: 68
                    radius: Theme.radius.s
                    color: Theme.surfaceRaised
                    border.width: lay.on ? 2 : 1
                    border.color: lay.on ? Theme.accent : lay.containsMouse ? Theme.fgDisabled : Theme.border
                    // The navigation part.
                    Rectangle {
                        readonly property string l: lay.modelData.id
                        readonly property bool horiz: l === "top" || l === "bottom"
                        x: l === "right" ? parent.width - width - 6 : 6
                        y: l === "bottom" ? parent.height - height - 6 : 6
                        width: horiz ? parent.width - 12 : l === "rail" ? 12 : 34
                        height: horiz ? 12 : parent.height - 12
                        radius: 3
                        color: lay.on ? Qt.alpha(Theme.accent, 0.5) : Theme.pressed
                    }
                    // Page lines.
                    Column {
                        readonly property string l: lay.modelData.id
                        x: l === "left" ? 48 : l === "rail" ? 26 : 10
                        y: l === "top" ? 26 : 12
                        spacing: 5
                        Repeater {
                            model: 3
                            Rectangle {
                                required property int index
                                width: [44, 56, 36][index]
                                height: 4
                                radius: 2
                                color: Theme.fgDisabled
                            }
                        }
                    }
                }
                StyledText {
                    anchors.top: mini.bottom
                    anchors.topMargin: 6
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: lay.modelData.name
                    color: lay.on ? Theme.fg : Theme.fgMuted
                    font.pixelSize: Theme.font.small
                    font.weight: lay.on ? Font.DemiBold : Font.Normal
                }
            }
        }
    }

    Section { text: "Corners" }

    // Preview: a small panel with a button and a chip, at the chosen radius.
    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.space.l
        Rectangle {
            implicitWidth: 150
            implicitHeight: 92
            radius: Theme.radius.l
            color: Theme.surfaceRaised
            border.width: 1
            border.color: Theme.border
            Behavior on radius { NumberAnimation { duration: Theme.anim.fast } }
            Rectangle {
                x: 12; y: 12
                width: 126; height: 28
                radius: Theme.radius.m
                color: Qt.alpha(Theme.accent, 0.25)
                Behavior on radius { NumberAnimation { duration: Theme.anim.fast } }
            }
            Rectangle {
                x: 12; y: 52
                width: 60; height: 28
                radius: Theme.radius.s
                color: Theme.hover
                border.width: 1
                border.color: Theme.border
                Behavior on radius { NumberAnimation { duration: Theme.anim.fast } }
            }
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: Theme.space.s
            Segmented {
                options: [{ label: "Square", value: 0 }, { label: "Small", value: 0.5 }, { label: "Default", value: 1 },
                          { label: "Large", value: 1.4 }, { label: "Round", value: 1.9 }]
                current: [0, 0.5, 1, 1.4, 1.9].find(v => Math.abs(v - Config.appearance.corners) < 0.01) ?? -1
                onSelected: value => Config.appearance.corners = value
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.space.m
                Slider {
                    Layout.fillWidth: true
                    from: 0
                    to: 200
                    stepSize: 5
                    showTicks: false
                    value: Math.round(Config.appearance.corners * 100)
                    onMoved: v => Config.appearance.corners = v / 100
                }
                StyledText {
                    Layout.preferredWidth: 44
                    horizontalAlignment: Text.AlignRight
                    text: Math.round(Config.appearance.corners * 100) + "%"
                    color: Theme.fgMuted
                    tabular: true
                }
            }
        }
    }
    SettingRow {
        title: "Window corners too"
        description: "Rounds Hyprland's window corners to match (your own rounding × this setting). Off keeps Hyprland's rounding as it is."
        Toggle {
            checked: Config.appearance.windowCorners
            onToggled: value => Config.appearance.windowCorners = value
        }
    }

    Section { text: "Fonts" }

    StyledText {
        Layout.fillWidth: true
        text: "Interface (bar, panels, Settings)"
        color: Theme.fgMuted
        font.pixelSize: Theme.font.small
    }
    FontPicker {
        current: Config.appearance.fontFamily === "Inter" ? "" : Config.appearance.fontFamily
        defaultLabel: "Inter (default)"
        onPicked: family => Config.appearance.fontFamily = family || "Inter"
    }
    StyledText {
        Layout.fillWidth: true
        Layout.topMargin: Theme.space.s
        text: "Desktop widgets"
        color: Theme.fgMuted
        font.pixelSize: Theme.font.small
    }
    FontPicker {
        current: Config.appearance.widgetFont
        defaultLabel: "Same as interface"
        onPicked: family => Config.appearance.widgetFont = family
    }
}
