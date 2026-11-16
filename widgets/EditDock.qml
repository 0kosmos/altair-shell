// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Layouts
import qs.components
import qs.core
import qs.services
import qs.theme

// Edit mode's dock: slides up from the bottom; click a widget type to add it
// in the middle of the screen; "Done" leaves edit mode (everything is saved
// as it changes). A toolbar above the list: widget settings, Select (pick
// several widgets to move or delete together), Undo, Clear all.
Item {
    id: dock

    // Where new widgets go: { x, y, w, h } relative to the monitor.
    required property var area
    required property string monitor
    property bool shown: false

    width: Math.max(row.implicitWidth, tools.implicitWidth) + Theme.space.m * 2
    height: 108 + 44
    opacity: shown ? 1 : 0
    transform: Translate {
        y: dock.shown ? 0 : 40
        Behavior on y {
            NumberAnimation { duration: Theme.anim.normal; easing.type: Theme.anim.easingSlide }
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

    RowLayout {
        id: tools
        anchors.top: parent.top
        anchors.topMargin: Theme.space.m
        anchors.horizontalCenter: parent.horizontalCenter
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
    }

    RowLayout {
        id: row
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: (108 - 86) / 2
        spacing: Theme.space.s

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

        Rectangle {
            Layout.fillHeight: true
            Layout.topMargin: Theme.space.m
            Layout.bottomMargin: Theme.space.m
            implicitWidth: 1
            color: Theme.border
        }

        // "Done": an accent pill.
        MouseArea {
            id: done
            Layout.leftMargin: Theme.space.xs
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
}
