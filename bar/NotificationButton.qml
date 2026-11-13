// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import qs.components
import qs.core
import qs.services
import qs.theme

// Bell: opens the notification centre. A dot marks unread history; a crossed
// bell means Do not disturb is on.
BarButton {
    onClicked: ShellState.toggle("notifications")

    Icon {
        name: Notifs.dnd ? "notifications_off" : "notifications"
        fill: ShellState.openPanel === "notifications" ? 1 : 0
        color: Notifs.dnd ? Theme.fgMuted : Theme.fg

        Rectangle {
            visible: Notifs.count > 0 && !Notifs.dnd
            width: 7
            height: 7
            radius: 3.5
            color: Theme.accent
            border.width: 1.5
            border.color: Theme.base
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.rightMargin: -1
            anchors.topMargin: 1
        }
    }
}
