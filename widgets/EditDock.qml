// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Layouts
import qs.components
import qs.services
import qs.theme

// Edit mode's dock: slides up from the bottom; click a widget type to add it
// in the middle of the screen; "Done" leaves edit mode (everything is saved
// as it changes).
Item {
    id: dock

    // Where new widgets go: { x, y, w, h } relative to the monitor.
    required property var area
    required property string monitor
    property bool shown: false

    width: row.implicitWidth + Theme.space.m * 2
    height: 108
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

    RowLayout {
        id: row
        anchors.centerIn: parent
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
