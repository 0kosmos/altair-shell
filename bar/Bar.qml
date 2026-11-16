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

        // Drag the bar by an empty spot to another screen edge: the nearest
        // edge to the pointer is shown (BarMoveHint) and taken on release.
        // Under everything else, so the clock, buttons and tray keep their
        // clicks.
        MouseArea {
            id: barDrag
            anchors.fill: parent
            hoverEnabled: true
            preventStealing: true
            cursorShape: dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor
            property point pressAt
            property bool dragging: false

            // This window's top-left on its screen (from where the bar sits).
            function origin(): point {
                const sw = win.screen.width, sh = win.screen.height, g = Theme.barGap;
                switch (win.pos) {
                case "bottom": return Qt.point(g, sh - g - win.height);
                case "right": return Qt.point(sw - g - win.width, g);
                default: return Qt.point(g, g);
                }
            }
            function targetAt(m): string {
                const o = origin();
                const x = o.x + m.x, y = o.y + m.y;
                const sw = win.screen.width, sh = win.screen.height;
                const d = { top: y, bottom: sh - y, left: x, right: sw - x };
                return Object.keys(d).reduce((a, b) => d[b] < d[a] ? b : a);
            }

            onPressed: mouse => {
                pressAt = Qt.point(mouse.x, mouse.y);
                dragging = false;
            }
            onPositionChanged: mouse => {
                if (!pressed)
                    return;
                if (!dragging && Math.hypot(mouse.x - pressAt.x, mouse.y - pressAt.y) > 12) {
                    dragging = true;
                    ShellState.barDragScreen = win.screen.name;
                }
                if (dragging)
                    ShellState.barDragTarget = targetAt(mouse);
            }
            onReleased: {
                if (dragging && ShellState.barDragTarget && ShellState.barDragTarget !== Theme.barPosition)
                    Config.appearance.barPosition = ShellState.barDragTarget;
                dragging = false;
                ShellState.barDragTarget = "";
            }
            onCanceled: {
                dragging = false;
                ShellState.barDragTarget = "";
            }
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
