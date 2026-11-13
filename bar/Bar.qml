// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.theme

// The top (or bottom) bar: one floating panel per screen.
Variants {
    model: Quickshell.screens

    PanelWindow {
        id: win

        required property var modelData
        screen: modelData

        WlrLayershell.namespace: "altair-bar"
        WlrLayershell.layer: WlrLayer.Top

        anchors {
            top: Theme.barAtTop
            bottom: !Theme.barAtTop
            left: true
            right: true
        }
        margins {
            top: Theme.barAtTop ? Theme.barGap : 0
            bottom: Theme.barAtTop ? 0 : Theme.barGap
            left: Theme.barGap
            right: Theme.barGap
        }

        implicitHeight: Theme.barHeight
        color: "transparent"

        // Blur is drawn by the compositor (ext-background-effect) behind exactly
        // this rounded shape. null = no blur, e.g. in low-power mode.
        BackgroundEffect.blurRegion: Theme.blur ? blurShape : null
        Region {
            id: blurShape
            item: background
            radius: Theme.radius.m
        }

        Rectangle {
            id: background
            anchors.fill: parent
            radius: Theme.radius.m
            color: Theme.surface
            border.width: 1
            border.color: Theme.border

            Behavior on color {
                ColorAnimation { duration: Theme.anim.normal }
            }
        }

        Workspaces {
            anchors.left: parent.left
            anchors.leftMargin: Theme.space.s
            anchors.verticalCenter: parent.verticalCenter
            monitor: Hyprland.monitorFor(win.screen)
        }

        Clock {
            anchors.centerIn: parent
        }

        RowLayout {
            anchors.right: parent.right
            anchors.rightMargin: Theme.space.xs
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0

            Tray {}
            Volume {}
            NetworkStatus {}
            BatteryStatus {}
            NotificationButton {}
        }
    }
}
