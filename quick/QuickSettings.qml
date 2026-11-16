// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.components
import qs.core
import qs.services
import qs.theme

// Quick settings (SUPER + A, the bar's tune button, or
// `qs -c altair ipc call panels toggle quick`): the switches used most,
// volume and brightness, and shortcuts to lock, power and Settings.
// The network, Bluetooth, brightness and recorder menus stay as they are;
// tiles with an arrow open them.
AltairPanel {
    id: root

    name: "quick"
    dock: Theme.barVertical ? Theme.barPosition : Theme.barAtTop ? "top" : "bottom"
    centerVertically: Theme.barVertical
    fullWidth: false
    along: "end"
    slideDistance: 12
    panelWidth: 392
    property real contentHeight: 400
    panelHeight: contentHeight

    content: Component {
        FocusScope {
            focus: true
            Binding {
                target: root
                property: "contentHeight"
                value: col.implicitHeight + Theme.space.l * 2
            }

            ColumnLayout {
                id: col
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Theme.space.l
                spacing: Theme.space.m

                // ---- Header: name + shortcuts ----------------------------------------
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.space.xs
                    StyledText {
                        Layout.fillWidth: true
                        text: Quickshell.env("USER") ?? ""
                        font.pixelSize: Theme.font.title
                        font.weight: Font.DemiBold
                    }
                    IconButton {
                        icon: "lock"
                        onClicked: {
                            ShellState.close();
                            Locker.lock();
                        }
                    }
                    IconButton {
                        icon: "power_settings_new"
                        onClicked: ShellState.open("power")
                    }
                    IconButton {
                        icon: "settings"
                        onClicked: {
                            ShellState.close();
                            ShellState.open("settings");
                        }
                    }
                }

                // ---- Tiles ------------------------------------------------------------
                GridLayout {
                    id: tiles
                    Layout.fillWidth: true
                    columns: 2
                    readonly property int visibleTiles: (Network.wifiDevice !== null ? 1 : 1) + (Bt.available ? 1 : 0) + 2
                        + (Audio.micAvailable ? 1 : 0) + 1 + (Recorder.available ? 1 : 0) + 1
                    rowSpacing: Theme.space.s
                    columnSpacing: Theme.space.s

                    Tile {
                        visible: Network.wifiDevice !== null
                        icon: Network.wifiEnabled ? "wifi" : "wifi_off"
                        title: "Wi-Fi"
                        detail: !Network.wifiEnabled ? (Network.kind === "wired" ? "Off · on wired" : "Off")
                            : Network.kind === "wifi" ? Network.name : Network.kind === "wired" ? "On · using wired" : "Not connected"
                        on: Network.wifiEnabled
                        onToggled: Network.setWifi(!Network.wifiEnabled)
                        more: "network"
                    }
                    Tile {
                        visible: Network.wifiDevice === null
                        icon: Network.icon
                        title: "Network"
                        detail: Network.kind === "none" ? "Offline" : Network.name
                        on: Network.kind !== "none"
                        onToggled: ShellState.open("network")
                        more: "network"
                    }
                    Tile {
                        visible: Bt.available
                        icon: Bt.icon
                        title: "Bluetooth"
                        detail: !Bt.enabled ? "Off" : Bt.connected.length === 1 ? (Bt.connected[0].name || "1 device")
                            : Bt.connected.length > 1 ? Bt.connected.length + " devices" : "On"
                        on: Bt.enabled
                        onToggled: Bt.setEnabled(!Bt.enabled)
                        more: "bluetooth"
                    }
                    Tile {
                        icon: Config.notifications.doNotDisturb ? "do_not_disturb_on" : "notifications"
                        title: "Do not disturb"
                        detail: Config.notifications.doNotDisturb ? "On: only urgent ones" : "Off"
                        on: Config.notifications.doNotDisturb
                        onToggled: Config.notifications.doNotDisturb = !Config.notifications.doNotDisturb
                    }
                    Tile {
                        icon: "nightlight"
                        title: "Night light"
                        detail: Display.nightLight ? Math.round(6500 - Display.warmth * 3200) + " K" : "Off"
                        on: Display.nightLight
                        onToggled: Display.toggleNightLight()
                        more: "brightness"
                    }
                    Tile {
                        visible: Audio.micAvailable
                        icon: Audio.micMuted ? "mic_off" : "mic"
                        title: "Microphone"
                        detail: Audio.micMuted ? "Muted" : "On"
                        on: !Audio.micMuted
                        onToggled: Audio.toggleMicMute()
                    }
                    Tile {
                        icon: Locker.keepAwake ? "coffee" : "bedtime"
                        title: "Keep awake"
                        detail: Locker.keepAwake ? "No lock on idle" : Locker.idleMinutes > 0 ? "Locks after " + Locker.idleMinutes + " min" : "Idle lock is off"
                        on: Locker.keepAwake
                        onToggled: Locker.keepAwake = !Locker.keepAwake
                    }
                    Tile {
                        visible: Recorder.available
                        icon: Recorder.recording ? "stop_circle" : "screen_record"
                        title: Recorder.recording ? "Stop recording" : "Record screen"
                        detail: Recorder.recording ? "Recording…" : Recorder.target === "region" ? "Region" : "Whole screen"
                        on: Recorder.recording
                        danger: Recorder.recording
                        onToggled: {
                            ShellState.close();
                            Recorder.toggle();
                        }
                        more: "recorder"
                    }
                    Tile {
                        // Spans both columns when it would be alone in its row.
                        Layout.columnSpan: tiles.visibleTiles % 2 === 1 ? 2 : 1
                        icon: "energy_savings_leaf"
                        title: "Low power"
                        detail: Config.performance.lowPower ? "Effects off" : "Off"
                        on: Config.performance.lowPower
                        onToggled: Config.performance.lowPower = !Config.performance.lowPower
                    }
                }

                // ---- Sliders ----------------------------------------------------------
                SliderRow {
                    visible: Audio.available
                    icon: Audio.muted || Audio.volume === 0 ? "volume_off" : Audio.volume < 0.5 ? "volume_down" : "volume_up"
                    value: Math.round(Audio.volume * 100)
                    muted: Audio.muted
                    onIconClicked: Audio.toggleMute()
                    onMoved: v => Audio.setVolume(v / 100)
                }
                SliderRow {
                    icon: Display.icon
                    value: Display.brightness
                    from: Display.hasHardware ? 0 : 20
                    onIconClicked: ShellState.open("brightness")
                    onMoved: v => Display.setBrightness(v)
                }
            }
        }
    }

    // ---- A toggle tile: click to switch; the arrow opens its menu ----------------------
    component Tile: MouseArea {
        id: tile
        property string icon
        property string title
        property string detail
        property bool on: false
        property bool danger: false
        property string more: ""           // panel the arrow opens ("" = no arrow)
        signal toggled()

        Layout.fillWidth: true
        Layout.preferredWidth: 1
        implicitHeight: 58
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            Sounds.toggled(!tile.on);
            tile.toggled();
        }
        scale: pressed ? Theme.anim.pressScale : 1
        Behavior on scale { NumberAnimation { duration: Theme.anim.fast; easing.type: Easing.OutBack; easing.overshoot: 2.5 } }

        Rectangle {
            anchors.fill: parent
            radius: Theme.radius.m
            color: tile.danger ? Qt.alpha(Theme.critical, tile.containsMouse ? 0.32 : 0.24)
                : tile.on ? (tile.containsMouse ? Qt.lighter(Theme.accent, 1.08) : Theme.accent)
                : tile.containsMouse ? Theme.pressed : Theme.surfaceRaised
            border.width: tile.on ? 0 : 1
            border.color: Theme.border
            Behavior on color { ColorAnimation { duration: Theme.anim.fast } }
        }
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Theme.space.m
            anchors.rightMargin: tile.more ? 2 : Theme.space.m
            spacing: Theme.space.s
            Icon {
                name: tile.icon
                fill: tile.on ? 1 : 0
                color: tile.on && !tile.danger ? Theme.onAccent : Theme.fg
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                StyledText {
                    Layout.fillWidth: true
                    text: tile.title
                    font.weight: Font.DemiBold
                    font.pixelSize: Theme.font.small + 1
                    color: tile.on && !tile.danger ? Theme.onAccent : Theme.fg
                    elide: Text.ElideRight
                }
                StyledText {
                    Layout.fillWidth: true
                    text: tile.detail
                    font.pixelSize: Theme.font.small
                    color: tile.on && !tile.danger ? Qt.alpha(Theme.onAccent, 0.75) : Theme.fgMuted
                    elide: Text.ElideRight
                }
            }
            IconButton {
                visible: tile.more !== ""
                icon: "chevron_right"
                size: 30
                color: tile.on && !tile.danger ? Theme.onAccent : Theme.fgMuted
                onClicked: ShellState.open(tile.more)
            }
        }
    }

    // ---- Icon (click: mute / open its menu) + slider + value ----------------------------
    component SliderRow: RowLayout {
        id: sr
        property string icon
        property int value: 0
        property int from: 0
        property bool muted: false
        signal moved(int v)
        signal iconClicked()
        Layout.fillWidth: true
        spacing: Theme.space.s
        IconButton {
            icon: sr.icon
            size: 32
            iconSize: 20
            color: sr.muted ? Theme.fgDisabled : Theme.fg
            onClicked: sr.iconClicked()
        }
        Slider {
            Layout.fillWidth: true
            from: sr.from
            to: 100
            stepSize: 1
            showTicks: false
            value: sr.value
            opacity: sr.muted ? 0.5 : 1
            onMoved: v => sr.moved(v)
        }
        StyledText {
            Layout.preferredWidth: 40
            horizontalAlignment: Text.AlignRight
            text: sr.value + "%"
            color: Theme.fgMuted
            font.pixelSize: Theme.font.small
            tabular: true
        }
    }
}
