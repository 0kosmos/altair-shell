// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Layouts
import qs.components
import qs.core
import qs.theme

// Settings navigation as a column: the full sidebar (icons, names, group
// headings) or, with `rail`, a slim column of icons that show the page's
// name on hover. A marker slides to the selected page.
Rectangle {
    id: root

    required property var pages
    required property string current
    property bool rail: false
    // Which side of the window it is on (for the rounded outer corners).
    property bool onRight: false
    signal picked(string id)

    implicitWidth: rail ? 68 : 230
    color: Theme.surfaceRaised
    topLeftRadius: onRight ? 0 : Theme.radius.m
    bottomLeftRadius: onRight ? 0 : Theme.radius.m
    topRightRadius: onRight ? Theme.radius.m : 0
    bottomRightRadius: onRight ? Theme.radius.m : 0
    Behavior on implicitWidth { NumberAnimation { duration: Theme.anim.normal; easing.type: Theme.anim.easingSlide } }

    // The selected row (set by the rows), for the sliding marker.
    property Item selectedRow: null
    // Rail: the hovered page's name, shown beside the rail (outside the
    // scrolling list, so it isn't clipped).
    property string tipText: ""
    property real tipY: 0
    z: 2

    Rectangle {
        visible: root.rail && root.tipText !== ""
        z: 10
        x: root.onRight ? -width - 8 : root.width + 8
        y: root.tipY - height / 2
        width: tipLabel.implicitWidth + 16
        height: 26
        radius: Theme.pill(26)
        color: Theme.base
        border.width: 1
        border.color: Theme.border
        StyledText {
            id: tipLabel
            anchors.centerIn: parent
            text: root.tipText
            font.pixelSize: Theme.font.small
        }
    }

    Flickable {
        id: flick
        anchors.fill: parent
        anchors.margins: root.rail ? Theme.space.s : Theme.space.m
        contentHeight: col.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        // Sliding highlight behind the selected row.
        Rectangle {
            id: marker
            visible: root.selectedRow !== null
            x: 0
            width: col.width
            height: root.selectedRow?.height ?? 0
            y: root.selectedRow ? root.selectedRow.mapToItem(col, 0, 0).y : 0
            radius: Theme.radius.s
            color: Qt.alpha(Theme.accent, 0.16)
            Behavior on y { NumberAnimation { duration: Theme.anim.normal; easing.type: Theme.anim.easingSlide } }
            // A short accent bar on the outer edge.
            Rectangle {
                width: 3
                height: parent.height * 0.5
                radius: 1.5
                anchors.verticalCenter: parent.verticalCenter
                x: root.onRight ? parent.width - width : 0
                color: Theme.accent
            }
        }

        ColumnLayout {
            id: col
            width: flick.width
            spacing: 2

            StyledText {
                visible: !root.rail
                Layout.leftMargin: Theme.space.s
                Layout.topMargin: Theme.space.s
                Layout.bottomMargin: Theme.space.m
                text: "Settings"
                font.pixelSize: Theme.font.title
                font.weight: Font.DemiBold
            }
            Icon {
                visible: root.rail
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: Theme.space.s
                Layout.bottomMargin: Theme.space.s
                name: "settings"
                size: 22
                color: Theme.accent
            }

            Repeater {
                model: root.pages

                ColumnLayout {
                    id: entry
                    required property var modelData
                    required property int index
                    readonly property bool firstOfGroup: index === 0 || root.pages[index - 1].group !== modelData.group

                    Layout.fillWidth: true
                    spacing: 2

                    // Group heading (a thin line in the rail).
                    StyledText {
                        visible: entry.firstOfGroup && !root.rail
                        Layout.leftMargin: Theme.space.s
                        Layout.topMargin: entry.index === 0 ? 0 : Theme.space.m
                        Layout.bottomMargin: 2
                        text: entry.modelData.group
                        color: Theme.fgDisabled
                        font.pixelSize: Theme.font.small
                        font.weight: Font.DemiBold
                        font.capitalization: Font.AllUppercase
                        font.letterSpacing: 0.6
                    }
                    Rectangle {
                        visible: entry.firstOfGroup && root.rail && entry.index > 0
                        Layout.alignment: Qt.AlignHCenter
                        Layout.topMargin: Theme.space.s
                        Layout.bottomMargin: Theme.space.s
                        implicitWidth: 24
                        implicitHeight: 1
                        color: Theme.border
                    }

                    MouseArea {
                        id: nav
                        readonly property bool selected: root.current === entry.modelData.id
                        onSelectedChanged: if (selected) root.selectedRow = nav
                        Component.onCompleted: if (selected) Qt.callLater(() => root.selectedRow = nav)

                        Layout.fillWidth: true
                        implicitHeight: root.rail ? 44 : 38
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.picked(entry.modelData.id)
                        scale: pressed ? Theme.anim.pressScale : 1
                        Behavior on scale {
                            NumberAnimation { duration: Theme.anim.fast; easing.type: Easing.OutBack; easing.overshoot: 2.5 }
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: Theme.radius.s
                            color: nav.containsMouse && !nav.selected ? Theme.hover : "transparent"
                            Behavior on color { ColorAnimation { duration: Theme.anim.fast } }
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: root.rail ? 0 : Theme.space.s
                            spacing: Theme.space.s

                            Icon {
                                Layout.alignment: root.rail ? Qt.AlignHCenter : Qt.AlignLeft
                                Layout.fillWidth: root.rail
                                name: entry.modelData.icon
                                size: root.rail ? 22 : Theme.font.icon
                                fill: nav.selected ? 1 : 0
                                color: nav.selected ? Theme.accent : Theme.fgMuted
                            }
                            StyledText {
                                visible: !root.rail
                                Layout.fillWidth: true
                                text: entry.modelData.label
                                font.weight: nav.selected ? Font.DemiBold : Font.Normal
                            }
                        }

                        // Rail: show the page's name beside it while hovered.
                        onContainsMouseChanged: {
                            if (containsMouse && root.rail) {
                                root.tipText = entry.modelData.label;
                                root.tipY = nav.mapToItem(root, 0, nav.height / 2).y;
                            } else if (root.tipText === entry.modelData.label) {
                                root.tipText = "";
                            }
                        }
                    }
                }
            }

            // Hints (full sidebar only).
            StyledText {
                visible: !root.rail
                Layout.topMargin: Theme.space.l
                Layout.leftMargin: Theme.space.s
                Layout.rightMargin: Theme.space.s
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                text: "Altair " + ShellState.version + "\nArrows / Tab: scroll and switch pages\nDouble-click an empty spot to re-centre\nCtrl+0: default size"
                color: Theme.fgDisabled
                font.pixelSize: Theme.font.small
            }
        }
    }
}
