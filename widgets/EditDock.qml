// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Layouts
import qs.components
import qs.core
import qs.services
import qs.theme

// Edit mode's dock: slides in from its edge; click a widget type to add it
// in the middle of the screen; "Done" leaves edit mode (everything is saved
// as it changes). A toolbar above the list: widget settings, Select (pick
// several widgets to move or delete together), Undo, Redo, Clear all, and a
// button that moves this panel to the next edge (bottom, right, top, left)
// when it is in the way. On the left/right it is a column (cards in 2 columns).
Item {
    id: dock

    // Where new widgets go: { x, y, w, h } relative to the monitor.
    required property var area
    required property string monitor
    property bool shown: false
    readonly property string side: ["top", "left", "right"].indexOf(Config.widgets.editDockSide) !== -1 ? Config.widgets.editDockSide : "bottom"
    readonly property bool vertical: side === "left" || side === "right"
    function nextSide(): void {
        const order = ["bottom", "right", "top", "left"];
        Config.widgets.editDockSide = order[(order.indexOf(side) + 1) % order.length];
    }

    width: content.implicitWidth + Theme.space.m * 2
    height: content.implicitHeight + Theme.space.m * 2
    opacity: shown ? 1 : 0
    // Slides in from its edge.
    transform: Translate {
        x: dock.shown ? 0 : dock.side === "left" ? -40 : dock.side === "right" ? 40 : 0
        y: dock.shown ? 0 : dock.side === "top" ? -40 : dock.side === "bottom" ? 40 : 0
        Behavior on x {
            NumberAnimation { duration: Theme.anim.slow; easing.type: Easing.OutQuint }
        }
        Behavior on y {
            NumberAnimation { duration: Theme.anim.slow; easing.type: Easing.OutQuint }
        }
    }
    Behavior on opacity {
        NumberAnimation { duration: Theme.anim.normal; easing.type: Theme.anim.easing }
    }

    GlassBackground {
        anchors.fill: parent
        radius: Theme.radius.l
        solidity: 0.4
    }

    // ---- Toolbar ----------------------------------------------------------------
    component Tool: MouseArea {
        id: tool
        property string icon
        property string label
        property bool on: false
        property bool danger: false
        implicitWidth: toolRow.implicitWidth + 22
        implicitHeight: 32
        hoverEnabled: true
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        opacity: enabled ? 1 : 0.4
        scale: pressed ? Theme.anim.pressScale : 1
        Behavior on scale { NumberAnimation { duration: Theme.anim.fast; easing.type: Easing.OutBack; easing.overshoot: 2.5 } }
        Behavior on opacity { NumberAnimation { duration: Theme.anim.fast } }
        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: tool.on ? Theme.accent : tool.danger ? Qt.alpha(Theme.critical, tool.containsMouse ? 0.3 : 0.18)
                : tool.containsMouse ? Theme.hover : Theme.surfaceRaised
            Behavior on color { ColorAnimation { duration: Theme.anim.fast } }
        }
        RowLayout {
            id: toolRow
            anchors.centerIn: parent
            spacing: 6
            Icon {
                name: tool.icon
                size: 16
                color: tool.on ? Theme.onAccent : tool.danger ? Theme.critical : Theme.fg
            }
            StyledText {
                text: tool.label
                font.pixelSize: Theme.font.small
                color: tool.on ? Theme.onAccent : tool.danger ? Theme.critical : Theme.fg
            }
        }
    }

    // Clear all: a second click within 3 s confirms.
    property bool clearArmed: false
    Timer {
        id: disarm
        interval: 3000
        onTriggered: dock.clearArmed = false
    }

    ColumnLayout {
        id: content
        anchors.centerIn: parent
        spacing: Theme.space.m

    Flow {
        id: tools
        Layout.alignment: Qt.AlignHCenter
        // As wide as the cards (wraps in the narrow side panel).
        Layout.preferredWidth: dock.vertical ? cards.implicitWidth : implicitWidthAll
        readonly property real implicitWidthAll: {
            let w = 0;
            for (let i = 0; i < children.length; i++)
                if (children[i].visible)
                    w += children[i].implicitWidth + spacing;
            return Math.max(0, w - spacing);
        }
        spacing: Theme.space.s

        Tool {
            icon: "settings"
            label: "Widget settings"
            onClicked: {
                Widgets.editing = false;   // Settings would sit under the edit layer
                ShellState.openSettings("widgets");
            }
        }
        Tool {
            icon: Widgets.selecting ? "check_box" : "select"
            label: Widgets.selecting ? (Widgets.picked.length > 0 ? Widgets.picked.length + " picked" : "Click widgets") : "Select"
            on: Widgets.selecting
            onClicked: Widgets.selecting = !Widgets.selecting
        }
        Tool {
            visible: Widgets.selecting && Widgets.picked.length > 0
            icon: "delete"
            label: "Delete"
            danger: true
            onClicked: Widgets.removePicked()
        }
        Tool {
            icon: "undo"
            label: "Undo"
            enabled: Widgets.canUndo
            onClicked: Widgets.undo()
        }
        Tool {
            icon: "redo"
            label: "Redo"
            enabled: Widgets.canRedo
            onClicked: Widgets.redo()
        }
        Tool {
            icon: "clear_all"
            label: dock.clearArmed ? "Click again to remove all" : "Clear all"
            danger: dock.clearArmed
            enabled: Widgets.items.length > 0
            onClicked: {
                if (dock.clearArmed) {
                    dock.clearArmed = false;
                    Widgets.clearAll();
                } else {
                    dock.clearArmed = true;
                    disarm.restart();
                }
            }
        }
        // Move this panel to the next edge (it may be in the way).
        Tool {
            icon: dock.side === "bottom" ? "arrow_forward" : dock.side === "right" ? "arrow_upward" : dock.side === "top" ? "arrow_back" : "arrow_downward"
            label: "Move panel"
            onClicked: dock.nextSide()
        }
        // "Done": an accent pill.
        MouseArea {
            id: done
            implicitWidth: doneText.implicitWidth + Theme.space.l * 2
            implicitHeight: 36
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: Widgets.editing = false
            scale: pressed ? Theme.anim.pressScale : 1
            Behavior on scale {
                NumberAnimation { duration: Theme.anim.fast; easing.type: Easing.OutBack; easing.overshoot: 2.5 }
            }
            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: done.containsMouse ? Qt.lighter(Theme.accent, 1.1) : Theme.accent
            }
            StyledText {
                id: doneText
                anchors.centerIn: parent
                text: "Done"
                color: Theme.onAccent
                font.weight: Font.DemiBold
            }
        }
    }

    GridLayout {
        id: cards
        Layout.alignment: Qt.AlignHCenter
        columns: dock.vertical ? 2 : -1
        rows: dock.vertical ? -1 : 1
        flow: dock.vertical ? GridLayout.LeftToRight : GridLayout.LeftToRight
        rowSpacing: Theme.space.s
        columnSpacing: Theme.space.s

        Repeater {
            model: Widgets.types

            MouseArea {
                id: card
                required property var modelData
                readonly property int count: Widgets.countOf(modelData.type)
                readonly property bool full: count >= Widgets.maxPerType
                implicitWidth: 96
                implicitHeight: 86
                hoverEnabled: true
                cursorShape: full ? Qt.ArrowCursor : Qt.PointingHandCursor
                opacity: full ? 0.45 : 1
                onClicked: if (!full) Widgets.add(modelData.type, dock.monitor, dock.area)
                Behavior on opacity {
                    NumberAnimation { duration: Theme.anim.fast }
                }
                scale: pressed ? Theme.anim.pressScale : 1
                Behavior on scale {
                    NumberAnimation { duration: Theme.anim.fast; easing.type: Easing.OutBack; easing.overshoot: 2.5 }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.radius.m
                    color: card.containsMouse ? Theme.hover : "transparent"
                    Behavior on color {
                        ColorAnimation { duration: Theme.anim.fast }
                    }
                }
                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: Theme.space.xs
                    Icon {
                        Layout.alignment: Qt.AlignHCenter
                        name: card.modelData.icon
                        size: 26
                    }
                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: card.modelData.name
                        font.pixelSize: Theme.font.small
                        color: Theme.fgMuted
                    }
                    // How many are placed, e.g. "2/3" (nothing when none).
                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        visible: card.count > 0
                        text: card.count + "/" + Widgets.maxPerType
                        font.pixelSize: 10
                        color: card.full ? Theme.accent : Theme.fgDisabled
                        tabular: true
                    }
                }
            }
        }

    }
    }
}
