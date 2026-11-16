// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.components
import qs.core
import qs.services
import qs.theme

// Network menu, opened from the network icon in the bar (or
// `qs -c altair ipc call panels toggle network`).
//
// Top: the current connection with its details (IP, gateway, DNS, MAC; click
// a value to copy it). Below: Wi-Fi on/off and the networks in range; click
// one to connect (a password field opens for new secured networks), click
// the connected one for Disconnect / Forget.
//
// Scanning runs only while this menu is open, and the details are read once
// when it opens (services/Network.qml); nothing is polled.
AltairPanel {
    id: root

    name: "network"
    dock: Theme.barVertical ? Theme.barPosition : Theme.barAtTop ? "top" : "bottom"
    centerVertically: Theme.barVertical
    fullWidth: false
    along: "end"
    slideDistance: 12
    panelWidth: 380
    // Follows the content (set by it), within limits.
    property real contentHeight: 260
    panelHeight: Math.max(160, Math.min(660, contentHeight))

    property bool counted: false
    onOpenChanged: {
        if (open && !counted) {
            Network.scanUsers++;
            counted = true;
            Network.refreshDetails();
        } else if (!open && counted) {
            Network.scanUsers--;
            counted = false;
        }
    }
    Connections {
        target: Network
        function onActiveDeviceChanged(): void {
            if (root.open)
                Network.refreshDetails();
        }
    }

    content: Component {
        FocusScope {
            id: scope
            focus: true
            // The network whose row is open (password or actions), by name.
            property string expanded: ""

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

                // ---- Header ----------------------------------------------------
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.space.s
                    StyledText {
                        Layout.fillWidth: true
                        text: "Network"
                        font.pixelSize: Theme.font.title
                        font.weight: Font.DemiBold
                    }
                    StyledText {
                        visible: Network.wifiDevice !== null
                        text: "Wi-Fi"
                        color: Theme.fgMuted
                        font.pixelSize: Theme.font.small
                    }
                    Toggle {
                        visible: Network.wifiDevice !== null
                        enabled: Network.wifiHardware
                        checked: Network.wifiEnabled
                        onToggled: value => Network.setWifi(value)
                    }
                }

                // ---- Current connection ----------------------------------------
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: current.implicitHeight + Theme.space.m * 2
                    radius: Theme.radius.m
                    color: Theme.surfaceRaised
                    border.width: 1
                    border.color: Theme.border

                    ColumnLayout {
                        id: current
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: Theme.space.m
                        spacing: Theme.space.s

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Theme.space.m
                            Rectangle {
                                implicitWidth: 38
                                implicitHeight: 38
                                radius: 19
                                color: Network.kind === "none" ? Theme.hover : Qt.alpha(Theme.accent, 0.18)
                                Icon {
                                    anchors.centerIn: parent
                                    name: Network.icon
                                    size: 20
                                    color: Network.kind === "none" ? Theme.fgMuted : Theme.accent
                                }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0
                                StyledText {
                                    Layout.fillWidth: true
                                    text: Network.kind === "none" ? "Not connected"
                                        : Network.kind === "wired" ? "Wired" + (Network.activeDevice ? " · " + Network.activeDevice.name : "")
                                        : Network.name
                                    font.weight: Font.DemiBold
                                    elide: Text.ElideRight
                                }
                                StyledText {
                                    Layout.fillWidth: true
                                    text: Network.kind === "none" ? (Network.wifiDevice && Network.wifiEnabled ? "Pick a network below." : "No cable or Wi-Fi connection.")
                                        : Network.kind === "wired" ? "Connected" + (Network.linkSpeed ? " · " + Network.linkSpeed : "")
                                        : "Connected · signal " + Math.round(Network.strength * 100) + " %"
                                    color: Theme.fgMuted
                                    font.pixelSize: Theme.font.small
                                    elide: Text.ElideRight
                                }
                            }
                            // Internet reachability (NetworkManager's check).
                            Rectangle {
                                visible: Network.kind !== "none"
                                implicitWidth: netLabel.implicitWidth + 16
                                implicitHeight: 22
                                radius: 11
                                color: Network.limited ? Qt.alpha(Theme.critical, 0.16) : Qt.alpha(Theme.accent, 0.16)
                                StyledText {
                                    id: netLabel
                                    anchors.centerIn: parent
                                    text: Network.limited ? "Limited" : "Internet"
                                    color: Network.limited ? Theme.critical : Theme.accent
                                    font.pixelSize: Theme.font.small - 1
                                    font.weight: Font.DemiBold
                                }
                            }
                        }

                        // Details: label + value, click a value to copy it.
                        ColumnLayout {
                            visible: Network.kind !== "none"
                            Layout.fillWidth: true
                            spacing: 0
                            Repeater {
                                model: {
                                    const d = Network.details;
                                    const rows = [["IP address", (d.ip ?? "").split("/")[0]], ["Gateway", d.gateway ?? ""],
                                                  ["DNS", (d.dns ?? []).join(", ")], ["IPv6", (d.ip6 ?? "").split("/")[0]],
                                                  ["MAC", d.mac ?? ""]];
                                    return rows.filter(r => r[1] !== "");
                                }
                                delegate: Item {
                                    id: cell
                                    required property var modelData
                                    required property int index
                                    Layout.fillWidth: true
                                    implicitHeight: 22
                                    StyledText {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: cell.modelData[0]
                                        color: Theme.fgMuted
                                        font.pixelSize: Theme.font.small
                                    }
                                    MouseArea {
                                        id: copy
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: Math.min(parent.width - 90, value.implicitWidth + 8)
                                        height: parent.height
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        property bool copied: false
                                        onClicked: {
                                            Sounds.click();
                                            Quickshell.clipboardText = cell.modelData[1];
                                            copied = true;
                                            copiedTimer.restart();
                                        }
                                        Timer {
                                            id: copiedTimer
                                            interval: 1200
                                            onTriggered: copy.copied = false
                                        }
                                        StyledText {
                                            id: value
                                            anchors.right: parent.right
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: Math.min(implicitWidth, parent.width)
                                            text: copy.copied ? "Copied" : cell.modelData[1]
                                            color: copy.copied ? Theme.accent : copy.containsMouse ? Theme.fg : Qt.alpha(Theme.fg, 0.85)
                                            font.pixelSize: Theme.font.small
                                            elide: Text.ElideLeft
                                            tabular: true
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // ---- Wi-Fi networks --------------------------------------------
                RowLayout {
                    visible: Network.wifiDevice !== null
                    Layout.fillWidth: true
                    Layout.topMargin: Theme.space.xs
                    StyledText {
                        Layout.fillWidth: true
                        text: "Wi-Fi networks"
                        color: Theme.fgMuted
                        font.pixelSize: Theme.font.small
                        font.weight: Font.DemiBold
                    }
                    StyledText {
                        visible: Network.wifiEnabled
                        text: Network.wifiNetworks.length === 0 ? "Searching…" : Network.wifiNetworks.length + " found"
                        color: Theme.fgDisabled
                        font.pixelSize: Theme.font.small
                    }
                }
                StyledText {
                    visible: Network.wifiDevice !== null && !Network.wifiEnabled
                    Layout.fillWidth: true
                    text: Network.wifiHardware ? "Wi-Fi is off." : "Wi-Fi is switched off by a hardware switch or airplane mode."
                    color: Theme.fgDisabled
                    font.pixelSize: Theme.font.small
                    wrapMode: Text.Wrap
                }

                Flickable {
                    visible: Network.wifiNetworks.length > 0
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.min(list.implicitHeight, 330)
                    contentHeight: list.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    ColumnLayout {
                        id: list
                        width: parent.width
                        spacing: 2
                        Repeater {
                            model: Network.wifiNetworks
                            delegate: WifiRow {
                                Layout.fillWidth: true
                                expanded: scope.expanded === modelData.name
                                onExpand: on => scope.expanded = on ? modelData.name : ""
                            }
                        }
                    }
                }
            }
        }
    }
}
