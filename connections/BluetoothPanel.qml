// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Layouts
import qs.components
import qs.core
import qs.services
import qs.theme

// Bluetooth menu, opened from the Bluetooth icon in the bar (or
// `qs -c altair ipc call panels toggle bluetooth`). On/off, paired devices
// (click: connect / disconnect, more: forget), and devices found nearby
// (click: pair and connect). Searches only while open.
AltairPanel {
    id: root

    name: "bluetooth"
    available: Bt.available
    dock: Theme.barVertical ? Theme.barPosition : Theme.barAtTop ? "top" : "bottom"
    centerVertically: Theme.barVertical
    fullWidth: false
    along: "end"
    slideDistance: 12
    panelWidth: 360
    property real contentHeight: 220
    panelHeight: Math.max(140, Math.min(620, contentHeight))

    property bool counted: false
    onOpenChanged: {
        if (open && !counted) {
            Bt.scanUsers++;
            counted = true;
        } else if (!open && counted) {
            Bt.scanUsers--;
            counted = false;
        }
    }

    content: Component {
        FocusScope {
            id: scope
            focus: true
            property string expanded: ""   // address of the device showing its actions

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

                RowLayout {
                    Layout.fillWidth: true
                    StyledText {
                        Layout.fillWidth: true
                        text: "Bluetooth"
                        font.pixelSize: Theme.font.title
                        font.weight: Font.DemiBold
                    }
                    Toggle {
                        enabled: !Bt.blocked
                        checked: Bt.enabled
                        onToggled: value => Bt.setEnabled(value)
                    }
                }

                StyledText {
                    visible: !Bt.enabled
                    Layout.fillWidth: true
                    text: Bt.blocked ? "Bluetooth is blocked (airplane mode or a hardware switch)." : "Bluetooth is off."
                    color: Theme.fgDisabled
                    font.pixelSize: Theme.font.small
                    wrapMode: Text.Wrap
                }

                // ---- Paired ----------------------------------------------------
                StyledText {
                    visible: Bt.enabled && Bt.paired.length > 0
                    text: "My devices"
                    color: Theme.fgMuted
                    font.pixelSize: Theme.font.small
                    font.weight: Font.DemiBold
                }
                ColumnLayout {
                    visible: Bt.enabled
                    Layout.fillWidth: true
                    spacing: 2
                    Repeater {
                        model: Bt.enabled ? Bt.paired : []
                        delegate: BtDeviceRow {
                            Layout.fillWidth: true
                            expanded: scope.expanded === modelData.address
                            onExpand: on => scope.expanded = on ? modelData.address : ""
                        }
                    }
                }

                // ---- Nearby ----------------------------------------------------
                RowLayout {
                    visible: Bt.enabled
                    Layout.fillWidth: true
                    Layout.topMargin: Theme.space.xs
                    StyledText {
                        Layout.fillWidth: true
                        text: "Nearby"
                        color: Theme.fgMuted
                        font.pixelSize: Theme.font.small
                        font.weight: Font.DemiBold
                    }
                    StyledText {
                        text: Bt.adapter?.discovering ? "Searching…" : ""
                        color: Theme.fgDisabled
                        font.pixelSize: Theme.font.small
                    }
                }
                StyledText {
                    visible: Bt.enabled && Bt.found.length === 0
                    Layout.fillWidth: true
                    text: "Put your device in pairing mode to see it here."
                    color: Theme.fgDisabled
                    font.pixelSize: Theme.font.small
                    wrapMode: Text.Wrap
                }
                Flickable {
                    visible: Bt.enabled && Bt.found.length > 0
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.min(nearby.implicitHeight, 260)
                    contentHeight: nearby.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    ColumnLayout {
                        id: nearby
                        width: parent.width
                        spacing: 2
                        Repeater {
                            model: Bt.enabled ? Bt.found : []
                            delegate: BtDeviceRow {
                                Layout.fillWidth: true
                            }
                        }
                    }
                }
            }
        }
    }
}
