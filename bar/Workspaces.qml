// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import Quickshell.Hyprland
import qs.services
import qs.theme

// Workspace dots. Shows at least `minCount` workspaces (more if higher ones
// exist). Dots: empty = faint, has windows = brighter, active = accent pill
// that slides between positions. Click to switch, scroll to cycle.
Item {
    id: root

    // The HyprlandMonitor this bar is on; its active workspace gets the pill.
    property var monitor
    property int minCount: 5

    readonly property int slot: 20
    readonly property var workspaces: Hyprland.workspaces.values
    readonly property int activeId: monitor?.activeWorkspace?.id ?? -1
    // Ignore special/named workspaces (id <= 0).
    readonly property int maxId: workspaces.reduce((m, w) => Math.max(m, w.id), 0)
    readonly property int count: Math.max(minCount, maxId)
    property int hoveredId: -1

    implicitWidth: count * slot
    implicitHeight: Theme.barHeight

    Repeater {
        model: root.count

        Item {
            id: cell
            required property int index
            readonly property int wsId: index + 1
            readonly property bool active: wsId === root.activeId
            readonly property bool occupied: {
                const ws = root.workspaces.find(w => w.id === cell.wsId);
                return ws !== undefined && ws.toplevels.values.length > 0;
            }

            x: index * root.slot
            width: root.slot
            height: parent.height

            Rectangle {
                anchors.centerIn: parent
                width: cell.occupied ? 8 : 6
                height: width
                radius: width / 2
                color: cell.occupied ? Theme.fgMuted : Theme.fgDisabled
                // The dot under the active pill is hidden (and not hover-scaled),
                // otherwise its edges peek out around the pill.
                opacity: cell.active ? 0 : 1
                scale: root.hoveredId === cell.wsId && !cell.active ? 1.35 : 1

                Behavior on opacity {
                    NumberAnimation { duration: Theme.anim.fast }
                }
                Behavior on width {
                    NumberAnimation { duration: Theme.anim.fast; easing.type: Theme.anim.easing }
                }
                Behavior on scale {
                    NumberAnimation { duration: Theme.anim.fast; easing.type: Theme.anim.easing }
                }
                Behavior on color {
                    ColorAnimation { duration: Theme.anim.fast }
                }
            }
        }
    }

    // Active indicator, drawn above the dots.
    Rectangle {
        visible: root.activeId >= 1 && root.activeId <= root.count
        width: 16
        height: 8
        radius: 4
        color: Theme.accent
        anchors.verticalCenter: parent.verticalCenter
        x: (root.activeId - 1) * root.slot + (root.slot - width) / 2

        Behavior on x {
            NumberAnimation { duration: Theme.anim.normal; easing.type: Theme.anim.easing }
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        function idAt(x: real): int {
            return Math.max(1, Math.min(root.count, Math.floor(x / root.slot) + 1));
        }

        onPositionChanged: mouse => root.hoveredId = idAt(mouse.x)
        onExited: root.hoveredId = -1
        onClicked: mouse => {
            const id = idAt(mouse.x);
            if (id !== root.activeId)
                Hypr.focusWorkspace(id);
        }

        property int wheelAccum: 0
        onWheel: wheel => {
            wheelAccum += wheel.angleDelta.y;
            if (Math.abs(wheelAccum) >= 120) {
                Hypr.cycleWorkspace(wheelAccum > 0 ? -1 : 1);
                wheelAccum = 0;
            }
        }
    }
}
