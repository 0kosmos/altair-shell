// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Widgets
import qs.components
import qs.services
import qs.theme

// One notification: icon/image, app name + age, summary, body, action buttons.
// Used for popups (inPopup: true) and in the notification centre.
Rectangle {
    id: card

    required property var notification
    property bool inPopup: false

    // Emitted by the close button; the owner decides how to animate it away.
    signal closeRequested()

    readonly property bool critical: notification?.urgency === NotificationUrgency.Critical
    readonly property var buttons: notification ? notification.actions.filter(a => a.identifier !== "default") : []
    readonly property bool hasDefault: notification ? notification.actions.some(a => a.identifier === "default") : false
    readonly property bool hovered: hover.containsMouse

    // Image > app icon > generic bell. Plain paths need a file:// scheme.
    readonly property string imageSource: {
        const n = notification;
        if (!n)
            return "";
        const toUrl = s => s.startsWith("/") ? "file://" + s : s;
        if (n.image)
            return toUrl(n.image);
        if (n.appIcon)
            return n.appIcon.includes("/") || n.appIcon.includes(":") ? toUrl(n.appIcon) : Quickshell.iconPath(n.appIcon, true);
        return "";
    }

    implicitHeight: content.implicitHeight + Theme.space.m * 2
    radius: Theme.radius.l
    // Popups draw their background with GlassBackground (below); cards in the
    // centre sit on the panel's glass and only need a light raised fill.
    color: inPopup ? "transparent" : Theme.surfaceRaised
    border.width: 1
    border.color: critical ? Theme.critical : inPopup ? "transparent" : Theme.border

    GlassBackground {
        z: -1
        anchors.fill: parent
        visible: card.inPopup
        radius: card.radius
    }

    MouseArea {
        id: hover
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: card.hasDefault ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: {
            if (!Notifs.invokeDefault(card.notification) && card.inPopup)
                card.closeRequested();
        }
    }

    RowLayout {
        id: content
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Theme.space.m
        spacing: Theme.space.m

        // ---- Icon ----------------------------------------------------------------
        Item {
            Layout.alignment: Qt.AlignTop
            implicitWidth: 36
            implicitHeight: 36

            ClippingRectangle {
                anchors.fill: parent
                radius: Theme.radius.s
                color: "transparent"
                visible: card.imageSource !== ""

                Image {
                    anchors.fill: parent
                    source: card.imageSource
                    sourceSize: Qt.size(72, 72)
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                }
            }
            Icon {
                anchors.centerIn: parent
                visible: card.imageSource === ""
                name: card.critical ? "warning" : "notifications"
                size: 24
                color: card.critical ? Theme.critical : Theme.fgMuted
            }
        }

        // ---- Text --------------------------------------------------------------
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.space.xs

                StyledText {
                    Layout.fillWidth: true
                    text: {
                        const app = card.notification?.appName ?? "";
                        const age = Notifs.ago(card.notification);
                        return app && age ? `${app} · ${age}` : app || age;
                    }
                    color: Theme.fgMuted
                    font.pixelSize: Theme.font.small
                }

                IconButton {
                    icon: "close"
                    size: 22
                    iconSize: 16
                    // Popups show it on hover; the centre always shows it.
                    opacity: !card.inPopup || card.hovered ? 1 : 0
                    Behavior on opacity {
                        NumberAnimation { duration: Theme.anim.fast }
                    }
                    onClicked: card.closeRequested()
                }
            }

            StyledText {
                Layout.fillWidth: true
                text: card.notification?.summary ?? ""
                font.weight: Font.DemiBold
                wrapMode: Text.Wrap
                maximumLineCount: 2
            }

            StyledText {
                Layout.fillWidth: true
                visible: text.length > 0
                text: Notifs.sanitize(card.notification?.body ?? "")
                textFormat: Text.StyledText
                color: Theme.fgMuted
                font.pixelSize: Theme.font.small + 1
                wrapMode: Text.Wrap
                maximumLineCount: 4
                lineHeight: 1.1
            }

            Flow {
                Layout.fillWidth: true
                Layout.topMargin: Theme.space.s
                visible: card.buttons.length > 0
                spacing: Theme.space.xs

                Repeater {
                    model: card.buttons

                    PillButton {
                        required property var modelData
                        text: modelData.text
                        onClicked: modelData.invoke()
                    }
                }
            }
        }
    }
}
