// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.components
import qs.core
import qs.services
import qs.theme

// Notification history panel, docked at the right. Toggle with the bell in the
// bar, SUPER+N, or `qs -c altair ipc call panels toggle notifications`.
AltairPanel {
    name: "notifications"
    alignRight: true
    panelWidth: 400
    panelHeight: 600

    content: Component {
        FocusScope {
            focus: true

            // ---- Header ----------------------------------------------------------
            RowLayout {
                id: header
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: Theme.space.m
                anchors.leftMargin: Theme.space.l
                height: 36
                spacing: Theme.space.xs

                StyledText {
                    Layout.fillWidth: true
                    text: "Notifications"
                    font.pixelSize: Theme.font.title
                    font.weight: Font.DemiBold
                }

                IconButton {
                    icon: Notifs.dnd ? "notifications_off" : "notifications_active"
                    color: Notifs.dnd ? Theme.accent : Theme.fgMuted
                    fill: Notifs.dnd ? 1 : 0
                    onClicked: Config.notifications.doNotDisturb = !Config.notifications.doNotDisturb
                }

                PillButton {
                    visible: Notifs.count > 0
                    text: "Clear all"
                    onClicked: Notifs.clearAll()
                }
            }

            StyledText {
                id: dndHint
                anchors.top: header.bottom
                anchors.left: parent.left
                anchors.leftMargin: Theme.space.l
                visible: Notifs.dnd
                text: "Do not disturb is on — only critical notifications pop up"
                color: Theme.fgMuted
                font.pixelSize: Theme.font.small
            }

            // ---- List ------------------------------------------------------------
            ListView {
                id: list
                anchors.top: Notifs.dnd ? dndHint.bottom : header.bottom
                anchors.topMargin: Theme.space.s
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: Theme.space.s
                clip: true
                spacing: Theme.space.s
                boundsBehavior: Flickable.StopAtBounds

                model: ScriptModel {
                    values: Notifs.history
                }

                delegate: NotificationCard {
                    required property var modelData
                    width: list.width
                    notification: modelData
                    onCloseRequested: Notifs.dismiss(modelData)
                }

                remove: Transition {
                    NumberAnimation { property: "opacity"; to: 0; duration: Theme.anim.fast }
                    NumberAnimation { property: "x"; to: 40; duration: Theme.anim.fast; easing.type: Theme.anim.easingIn }
                }
                displaced: Transition {
                    NumberAnimation { properties: "y"; duration: Theme.anim.normal; easing.type: Theme.anim.easing }
                }
                add: Transition {
                    NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.anim.normal }
                }

                // Empty state.
                Column {
                    anchors.centerIn: parent
                    visible: Notifs.count === 0
                    spacing: Theme.space.s

                    Icon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        name: "notifications_none"
                        size: 40
                        color: Theme.fgDisabled
                    }
                    StyledText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "No notifications"
                        color: Theme.fgMuted
                    }
                }
            }
        }
    }
}
