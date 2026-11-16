// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.components
import qs.core
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

        // Along its edge, with a gap to the screen edges.
        readonly property string pos: Theme.barPosition
        readonly property bool vertical: Theme.barVertical
        anchors {
            top: pos !== "bottom"
            bottom: pos !== "top"
            left: pos !== "right"
            right: pos !== "left"
        }
        margins {
            top: pos === "bottom" ? 0 : Theme.barGap
            bottom: pos === "top" ? 0 : Theme.barGap
            left: pos === "right" ? 0 : Theme.barGap
            right: pos === "left" ? 0 : Theme.barGap
        }

        implicitHeight: vertical ? 0 : Theme.barThickness
        implicitWidth: vertical ? Theme.barThickness : 0
        color: "transparent"

        // Blur is drawn by the compositor (ext-background-effect) behind exactly
        // this rounded shape. null = no blur, e.g. in low-power mode.
        BackgroundEffect.blurRegion: Theme.blur ? blurShape : null
        Region {
            id: blurShape
            item: background
            radius: Theme.radius.m
        }

        GlassBackground {
            id: background
            anchors.fill: parent
            radius: Theme.radius.m
        }

        Workspaces {
            x: win.vertical ? 0 : Theme.space.s
            y: win.vertical ? Theme.space.s : (parent.height - height) / 2
            vertical: win.vertical
            monitor: Hyprland.monitorFor(win.screen)
            minCount: Math.max(1, Math.min(10, Config.bar.workspaces))
        }

        Clock {
            anchors.centerIn: parent
        }

        // Status items: at the right end, or the bottom of a side bar.
        GridLayout {
            x: win.vertical ? (parent.width - width) / 2 : parent.width - width - Theme.space.xs
            y: win.vertical ? parent.height - height - Theme.space.xs : (parent.height - height) / 2
            flow: win.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
            rows: win.vertical ? -1 : 1
            columns: win.vertical ? 1 : -1
            rowSpacing: 0
            columnSpacing: 0

            Tray {}
            Volume {}
            NetworkStatus {}
            BatteryStatus {}
            RecordButton {}
            NotificationButton {}
            SettingsButton {}
        }
    }
}
