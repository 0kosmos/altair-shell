// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Layouts
import Quickshell.Bluetooth
import qs.components
import qs.services
import qs.theme

// One Bluetooth device in the Bluetooth menu. Paired: click connects or
// disconnects, the "more" button shows Forget. Not paired: click pairs and
// connects.
ColumnLayout {
    id: row

    required property var modelData
    property bool expanded: false
    signal expand(bool on)

    readonly property var dev: modelData
    readonly property bool isPaired: dev.paired || dev.bonded
    readonly property bool busy: dev.pairing || dev.state === BluetoothDeviceState.Connecting
        || dev.state === BluetoothDeviceState.Disconnecting

    spacing: 0

    MouseArea {
        id: hit
        Layout.fillWidth: true
        implicitHeight: 44
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            Sounds.click();
            if (row.busy)
                return;
            if (!row.isPaired)
                Bt.pairAndConnect(row.dev);
            else if (row.dev.connected)
                row.dev.disconnect();
            else
                row.dev.connect();
        }

        Rectangle {
            anchors.fill: parent
            radius: Theme.radius.s
            color: row.dev.connected ? Qt.alpha(Theme.accent, 0.12)
                : hit.containsMouse || row.expanded ? Theme.hover : "transparent"
            Behavior on color { ColorAnimation { duration: Theme.anim.fast } }
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Theme.space.s
            anchors.rightMargin: Theme.space.xs
            spacing: Theme.space.m

            Icon {
                name: Bt.deviceIcon(row.dev)
                size: 20
                color: row.dev.connected ? Theme.accent : Theme.fg
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                StyledText {
                    Layout.fillWidth: true
                    text: row.dev.name || row.dev.address
                    font.weight: row.dev.connected ? Font.DemiBold : Font.Normal
                    elide: Text.ElideRight
                }
                StyledText {
                    Layout.fillWidth: true
                    text: row.dev.pairing ? "Pairing…"
                        : row.dev.state === BluetoothDeviceState.Connecting ? "Connecting…"
                        : row.dev.state === BluetoothDeviceState.Disconnecting ? "Disconnecting…"
                        : row.dev.connected ? "Connected"
                        : row.isPaired ? "Not connected" : "Click to pair"
                    color: row.busy || row.dev.connected ? Theme.accent : Theme.fgMuted
                    font.pixelSize: Theme.font.small
                }
            }
            // Battery, when the device reports it (0–1).
            RowLayout {
                visible: row.dev.connected && row.dev.batteryAvailable
                spacing: 2
                Icon {
                    name: row.dev.battery > 0.8 ? "battery_full" : row.dev.battery > 0.5 ? "battery_5_bar"
                        : row.dev.battery > 0.2 ? "battery_3_bar" : "battery_1_bar"
                    size: 15
                    color: Theme.fgMuted
                }
                StyledText {
                    text: Math.round(row.dev.battery * 100) + "%"
                    color: Theme.fgMuted
                    font.pixelSize: Theme.font.small
                    tabular: true
                }
            }
            IconButton {
                visible: row.isPaired
                icon: "more_horiz"
                size: 28
                iconSize: 18
                onClicked: row.expand(!row.expanded)
            }
        }
    }

    Item {
        Layout.fillWidth: true
        implicitHeight: row.expanded ? 40 : 0
        clip: true
        Behavior on implicitHeight { NumberAnimation { duration: Theme.anim.fast; easing.type: Theme.anim.easing } }
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 40
            spacing: Theme.space.s
            PillButton {
                text: row.dev.trusted ? "Don't reconnect" : "Reconnect automatically"
                onClicked: row.dev.trusted = !row.dev.trusted
            }
            PillButton {
                text: "Forget"
                onClicked: {
                    row.dev.forget();
                    row.expand(false);
                }
            }
            Item { Layout.fillWidth: true }
        }
    }
}
