// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.components
import qs.core
import qs.services
import qs.theme

// The bar: one floating panel per screen, on any edge.
//
// Moving it: press on an empty spot and drag toward another edge. While
// dragging, this same window grows over the whole screen (transparent,
// still reserving only the bar's strip, so windows don't move): the pointer
// never leaves it, so the drag can't be lost to the desktop below (Hyprland
// moves the pointer to whatever surface it is over). The screen dims a
// little, a ghost bar glides to the nearest edge, the dock's outline shows
// where it will be and widgets glide out of the way (they read the preview
// edge, ShellState.barDragTarget). Release to put the bar there.
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
        readonly property bool dragging: barDrag.dragging
        readonly property int t: Theme.barThickness
        readonly property int g: Theme.barGap
        anchors {
            top: pos !== "bottom"
            bottom: pos !== "top"
            left: pos !== "right"
            right: pos !== "left"
        }
        // Dragging: no margins (the window reaches every screen edge) and the
        // reserved strip grows by the margin instead, so it stays the same.
        margins {
            top: dragging || pos === "bottom" ? 0 : g
            bottom: dragging || pos === "top" ? 0 : g
            left: dragging || pos === "right" ? 0 : g
            right: dragging || pos === "left" ? 0 : g
        }
        exclusionMode: ExclusionMode.Normal
        exclusiveZone: t + (dragging ? g : 0)

        implicitHeight: vertical ? 0 : dragging ? win.screen.height : t
        implicitWidth: vertical ? (dragging ? win.screen.width : t) : 0
        color: "transparent"

        // Blur is drawn by the compositor (ext-background-effect) behind exactly
        // this rounded shape. null = no blur, e.g. in low-power mode.
        BackgroundEffect.blurRegion: Theme.blur ? blurShape : null
        Region {
            id: blurShape
            item: background
            radius: Theme.radius.m
        }

        // The bar itself: the whole window normally; while dragging, its
        // strip at the edge (where it was), inside the full-screen window.
        Item {
            id: barBody
            x: !win.dragging ? 0 : win.pos === "right" ? win.width - win.g - win.t : win.g
            y: !win.dragging ? 0 : win.pos === "bottom" ? win.height - win.g - win.t : win.g
            width: !win.dragging ? win.width : win.vertical ? win.t : win.width - win.g * 2
            height: !win.dragging ? win.height : win.vertical ? win.height - win.g * 2 : win.t
            opacity: win.dragging ? 0.45 : 1
            Behavior on opacity { NumberAnimation { duration: Theme.anim.fast } }

        GlassBackground {
            id: background
            anchors.fill: parent
            radius: Theme.radius.m
        }

        // Drag the bar by an empty spot to another screen edge: the nearest
        // edge to the pointer is previewed (DragPreview) and taken on release.
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

            // The bar strip's top-left on its screen (it stays put while the
            // window grows for the drag, so this holds throughout).
            function origin(): point {
                const sw = win.screen.width, sh = win.screen.height, g = win.g, t = win.t;
                switch (win.pos) {
                case "bottom": return Qt.point(g, sh - g - t);
                case "right": return Qt.point(sw - g - t, g);
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

        // Along the bar (x, or y on a side bar), the three groups are laid
        // out by hand so the clock can sit in any of five places and the
        // others make room for it (Config.bar.clockPosition).
        readonly property string clockPos: ["left", "leftFirst", "right", "rightLast"].indexOf(Config.bar.clockPosition) !== -1
            ? Config.bar.clockPosition : "center"
        readonly property real length: win.vertical ? height : width
        readonly property real clockLen: win.vertical ? clockItem.height : clockItem.width
        readonly property real wsLen: win.vertical ? workspaces.height : workspaces.width
        readonly property real statusLen: win.vertical ? status.height : status.width
        readonly property real startPad: Theme.space.s
        readonly property real endPad: Theme.space.xs
        readonly property real groupGap: Theme.space.s
        readonly property real wsAt: clockPos === "leftFirst" ? startPad + clockLen + groupGap : startPad
        readonly property real statusAt: length - endPad - statusLen - (clockPos === "rightLast" ? clockLen + groupGap : 0)
        readonly property real clockAt: {
            switch (clockPos) {
            case "leftFirst": return startPad;
            case "left": return wsAt + wsLen + groupGap;
            case "right": return statusAt - groupGap - clockLen;
            case "rightLast": return length - endPad - clockLen;
            default: return Math.round((length - clockLen) / 2);
            }
        }

        Workspaces {
            id: workspaces
            x: win.vertical ? 0 : barBody.wsAt
            y: win.vertical ? barBody.wsAt : (parent.height - height) / 2
            vertical: win.vertical
            monitor: Hyprland.monitorFor(win.screen)
            minCount: Math.max(1, Math.min(10, Config.bar.workspaces))
        }

        Clock {
            id: clockItem
            x: win.vertical ? Math.round((parent.width - width) / 2) : barBody.clockAt
            y: win.vertical ? barBody.clockAt : Math.round((parent.height - height) / 2)
        }

        // Status items: at the right end, or the bottom of a side bar.
        GridLayout {
            id: status
            x: win.vertical ? (parent.width - width) / 2 : barBody.statusAt
            y: win.vertical ? barBody.statusAt : (parent.height - height) / 2
            flow: win.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
            rows: win.vertical ? -1 : 1
            columns: win.vertical ? 1 : -1
            rowSpacing: 0
            columnSpacing: 0

            Tray {}
            Volume {}
            NetworkStatus {}
            BluetoothButton {}
            BatteryStatus {}
            RecordButton {}
            NotificationButton {}
            SettingsButton {}
        }
        }

        // ---- Drag preview -------------------------------------------------------------
        DragPreview {
            anchors.fill: parent
            visible: win.dragging
            target: ShellState.barDragTarget || win.pos
            screenName: win.screen.name
        }
    }
}
