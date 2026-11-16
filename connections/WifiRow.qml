// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Layouts
import qs.components
import qs.services
import qs.theme

// (No `import Quickshell.Networking` here: its `Network` type would hide our
// Network service.)
//
// One Wi-Fi network in the network menu. Click: connect (saved or open
// networks), open a password field (new secured ones), or show Disconnect /
// Forget (the connected one, or a saved one).
ColumnLayout {
    id: row

    required property var modelData
    property bool expanded: false
    signal expand(bool on)

    readonly property var net: modelData
    readonly property bool secured: Network.secured(net)
    readonly property bool busy: net?.stateChanging ?? false
    property string error: ""

    spacing: 0

    Connections {
        target: row.net
        function onConnectionFailed(reason): void {
            row.error = Network.failText(reason);
            if (row.secured && !row.net.known)
                row.expand(true);
        }
        function onConnectedChanged(): void {
            if (row.net.connected) {
                row.error = "";
                if (row.expanded && !row.actions)
                    row.expand(false);
            }
        }
    }

    // What clicking the row shows: actions (connected/saved) or a password.
    readonly property bool actions: net.connected || net.known
    function activate(): void {
        error = "";
        if (net.connected) {
            expand(!expanded);
        } else if (net.known || !secured) {
            net.connect();
            expand(false);
        } else {
            expand(!expanded);
        }
    }

    MouseArea {
        id: hit
        Layout.fillWidth: true
        implicitHeight: 44
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            Sounds.click();
            row.activate();
        }
        // Right-click a saved network: its actions (Forget) without connecting.
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onPressed: mouse => {
            if (mouse.button === Qt.RightButton && row.net.known)
                row.expand(!row.expanded);
        }

        Rectangle {
            anchors.fill: parent
            radius: Theme.radius.s
            color: row.net.connected ? Qt.alpha(Theme.accent, 0.12)
                : hit.containsMouse || row.expanded ? Theme.hover : "transparent"
            Behavior on color { ColorAnimation { duration: Theme.anim.fast } }
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Theme.space.s
            anchors.rightMargin: Theme.space.s
            spacing: Theme.space.m

            Icon {
                name: Network.wifiIcon(Network.signalOf(row.net))
                size: 20
                color: row.net.connected ? Theme.accent : Theme.fg
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                StyledText {
                    Layout.fillWidth: true
                    text: row.net.name
                    font.weight: row.net.connected ? Font.DemiBold : Font.Normal
                    elide: Text.ElideRight
                }
                StyledText {
                    Layout.fillWidth: true
                    text: row.busy ? (row.net.connected ? "Disconnecting…" : "Connecting…")
                        : row.net.connected ? "Connected"
                        : row.net.known ? "Saved"
                        : row.secured ? "Secured" : "Open network"
                    color: row.busy || row.net.connected ? Theme.accent : Theme.fgMuted
                    font.pixelSize: Theme.font.small
                }
            }
            Icon {
                visible: row.secured
                name: "lock"
                size: 14
                color: Theme.fgDisabled
            }
            StyledText {
                text: Math.round(Network.signalOf(row.net) * 100) + "%"
                color: Theme.fgDisabled
                font.pixelSize: Theme.font.small
                tabular: true
            }
        }
    }

    StyledText {
        visible: row.error !== ""
        Layout.fillWidth: true
        Layout.leftMargin: 40
        Layout.bottomMargin: 4
        text: row.error
        color: Theme.critical
        font.pixelSize: Theme.font.small
        wrapMode: Text.Wrap
    }

    // ---- Expanded: password, or actions ----------------------------------------
    Item {
        Layout.fillWidth: true
        implicitHeight: row.expanded ? 44 : 0
        clip: true
        Behavior on implicitHeight { NumberAnimation { duration: Theme.anim.fast; easing.type: Theme.anim.easing } }

        // Password for a new secured network.
        RowLayout {
            visible: !row.actions
            anchors.fill: parent
            anchors.leftMargin: 40
            anchors.rightMargin: Theme.space.s
            spacing: Theme.space.s

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 32
                radius: Theme.radius.s
                color: Theme.pressed
                border.width: 1
                border.color: pass.activeFocus ? Theme.accent : Theme.border

                TextInput {
                    id: pass
                    anchors.fill: parent
                    anchors.leftMargin: Theme.space.s
                    anchors.rightMargin: 30
                    verticalAlignment: TextInput.AlignVCenter
                    echoMode: show.on ? TextInput.Normal : TextInput.Password
                    color: Theme.fg
                    font.family: Theme.font.family
                    font.pixelSize: Theme.font.body
                    clip: true
                    onAccepted: row.submit()
                    onTextEdited: Sounds.typing()

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: pass.text === ""
                        text: "Password"
                        color: Theme.fgDisabled
                    }
                }
                // Show / hide the password.
                MouseArea {
                    id: show
                    property bool on: false
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 30
                    cursorShape: Qt.PointingHandCursor
                    onClicked: on = !on
                    Icon {
                        anchors.centerIn: parent
                        name: show.on ? "visibility_off" : "visibility"
                        size: 16
                        color: Theme.fgMuted
                    }
                }
            }
            PillButton {
                id: join
                text: "Connect"
                enabled: pass.text.length >= 8
                opacity: enabled ? 1 : 0.5
                onClicked: row.submit()
            }
        }

        // Connected or saved: what you can do with it.
        RowLayout {
            visible: row.actions
            anchors.fill: parent
            anchors.leftMargin: 40
            anchors.rightMargin: Theme.space.s
            spacing: Theme.space.s
            PillButton {
                visible: row.net.connected
                text: "Disconnect"
                onClicked: {
                    row.net.disconnect();
                    row.expand(false);
                }
            }
            PillButton {
                visible: !row.net.connected
                text: "Connect"
                onClicked: {
                    row.net.connect();
                    row.expand(false);
                }
            }
            PillButton {
                text: "Forget"
                onClicked: {
                    row.net.forget();
                    row.expand(false);
                }
            }
            Item { Layout.fillWidth: true }
        }
    }

    // WPA passwords are 8–63 characters.
    function submit(): void {
        if (pass.text.length < 8)
            return;
        error = "";
        net.connectWithPsk(pass.text);
        pass.text = "";
    }

    // Focus the password field when it opens.
    onExpandedChanged: if (expanded && !actions) pass.forceActiveFocus()
}
