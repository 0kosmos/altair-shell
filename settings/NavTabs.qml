// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Layouts
import qs.components
import qs.theme

// Settings navigation as a row of tabs (layouts "top" and "bottom"): icon
// and name per page, small gaps between groups, an underline that slides to
// the selected tab. Scrolls sideways (wheel too) and keeps the selected tab
// in view.
Rectangle {
    id: root

    required property var pages
    required property string current
    property bool atBottom: false
    signal picked(string id)

    implicitHeight: 56
    color: Theme.surfaceRaised
    topLeftRadius: atBottom ? 0 : Theme.radius.m
    topRightRadius: atBottom ? 0 : Theme.radius.m
    bottomLeftRadius: atBottom ? Theme.radius.m : 0
    bottomRightRadius: atBottom ? Theme.radius.m : 0

    property Item selectedTab: null
    onSelectedTabChanged: Qt.callLater(reveal)
    // Scroll so the selected tab is fully visible.
    function reveal(): void {
        if (!selectedTab)
            return;
        const x = selectedTab.mapToItem(row, 0, 0).x;
        const target = Math.max(0, Math.min(flick.contentWidth - flick.width, x - (flick.width - selectedTab.width) / 2));
        scroller.to = target;
        scroller.restart();
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.space.l
        anchors.rightMargin: Theme.space.s
        spacing: Theme.space.m

        StyledText {
            text: "Settings"
            font.pixelSize: Theme.font.title
            font.weight: Font.DemiBold
        }

        Flickable {
            id: flick
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: row.implicitWidth
            contentHeight: height
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            flickableDirection: Flickable.HorizontalFlick
            NumberAnimation on contentX {
                id: scroller
                running: false
                duration: Theme.anim.normal
                easing.type: Theme.anim.easingSlide
            }

            // Wheel scrolls sideways.
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.NoButton
                onWheel: wheel => {
                    const d = wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : wheel.angleDelta.x;
                    flick.contentX = Math.max(0, Math.min(flick.contentWidth - flick.width, flick.contentX - d));
                }
            }

            Row {
                id: row
                height: flick.height
                spacing: 2

                Repeater {
                    model: root.pages

                    Row {
                        id: entry
                        required property var modelData
                        required property int index
                        readonly property bool firstOfGroup: index > 0 && root.pages[index - 1].group !== modelData.group
                        height: row.height
                        spacing: 2

                        // A thin divider between groups.
                        Item {
                            visible: entry.firstOfGroup
                            width: 13
                            height: parent.height
                            Rectangle {
                                anchors.centerIn: parent
                                width: 1
                                height: 20
                                color: Theme.border
                            }
                        }

                        MouseArea {
                            id: tab
                            readonly property bool selected: root.current === entry.modelData.id
                            onSelectedChanged: if (selected) root.selectedTab = tab
                            Component.onCompleted: if (selected) Qt.callLater(() => root.selectedTab = tab)
                            width: tabRow.implicitWidth + 20
                            height: parent.height
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.picked(entry.modelData.id)

                            Rectangle {
                                anchors.centerIn: parent
                                width: parent.width
                                height: 36
                                radius: Theme.radius.s
                                color: tab.selected ? Qt.alpha(Theme.accent, 0.14) : tab.containsMouse ? Theme.hover : "transparent"
                                Behavior on color { ColorAnimation { duration: Theme.anim.fast } }
                            }
                            RowLayout {
                                id: tabRow
                                anchors.centerIn: parent
                                spacing: 6
                                Icon {
                                    name: entry.modelData.icon
                                    fill: tab.selected ? 1 : 0
                                    color: tab.selected ? Theme.accent : Theme.fgMuted
                                }
                                StyledText {
                                    text: entry.modelData.label
                                    font.weight: tab.selected ? Font.DemiBold : Font.Normal
                                    color: tab.selected ? Theme.fg : Theme.fgMuted
                                }
                            }
                        }
                    }
                }
            }

            // The underline, sliding to the selected tab.
            Rectangle {
                visible: root.selectedTab !== null
                height: 3
                radius: 1.5
                color: Theme.accent
                y: root.atBottom ? 4 : flick.height - 7
                x: root.selectedTab ? root.selectedTab.mapToItem(row, 0, 0).x + 14 : 0
                width: root.selectedTab ? root.selectedTab.width - 28 : 0
                Behavior on x { NumberAnimation { duration: Theme.anim.normal; easing.type: Theme.anim.easingSlide } }
                Behavior on width { NumberAnimation { duration: Theme.anim.normal; easing.type: Theme.anim.easingSlide } }
            }
        }
    }
}
