// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.components
import qs.theme

// A tray app's menu, drawn in Altair's style instead of a native Qt menu.
// Submenus open in place (with a back row) rather than as cascading popups.
// Clicking outside closes it (popup focus grab).
PopupWindow {
    id: root

    required property var handle      // QsMenuHandle from SystemTrayItem.menu
    required property Item anchorItem
    signal dismissed()

    // Stack of opened submenus; the last one is shown.
    property list<var> stack: []
    readonly property var current: stack.length > 0 ? stack[stack.length - 1] : handle

    readonly property int menuWidth: 240
    readonly property int gap: 6

    anchor.item: anchorItem
    anchor.rect.x: 0
    anchor.rect.y: Theme.barAtTop ? anchorItem.height + gap : -gap
    anchor.rect.width: anchorItem.width
    anchor.rect.height: 1
    anchor.edges: Theme.barAtTop ? Edges.Bottom : Edges.Top
    anchor.gravity: Theme.barAtTop ? Edges.Bottom : Edges.Top

    grabFocus: true
    visible: true
    color: "transparent"
    implicitWidth: menuWidth
    implicitHeight: list.implicitHeight + Theme.space.xs * 2

    onVisibleChanged: if (!visible) dismissed()

    function close(): void {
        visible = false;
    }

    BackgroundEffect.blurRegion: Theme.blur ? blurShape : null
    Region {
        id: blurShape
        item: background
        radius: Theme.radius.m
    }

    QsMenuOpener {
        id: opener
        menu: root.current
    }

    Rectangle {
        id: background
        anchors.fill: parent
        radius: Theme.radius.m
        color: Theme.surface
        border.width: 1
        border.color: Theme.border

        // Open animation: short fade + slide toward the bar.
        opacity: 0
        transform: Translate {
            id: slide
            y: Theme.barAtTop ? -6 : 6
            Behavior on y {
                NumberAnimation { duration: Theme.anim.fast; easing.type: Theme.anim.easing }
            }
        }
        Component.onCompleted: {
            opacity = 1;
            slide.y = 0;
        }
        Behavior on opacity {
            NumberAnimation { duration: Theme.anim.fast; easing.type: Theme.anim.easing }
        }
    }

    ColumnLayout {
        id: list
        anchors.fill: parent
        anchors.margins: Theme.space.xs
        spacing: 0
        opacity: background.opacity
        transform: Translate { y: slide.y }

        // Back row inside submenus.
        MenuRow {
            visible: root.stack.length > 0
            iconName: "chevron_left"
            label: "Back"
            onClicked: root.stack = root.stack.slice(0, -1)
        }

        Repeater {
            model: opener.children

            Loader {
                id: entryLoader
                required property var modelData
                Layout.fillWidth: true
                sourceComponent: modelData.isSeparator ? separator : row

                Component {
                    id: separator
                    Rectangle {
                        implicitHeight: 1 + Theme.space.xs * 2
                        color: "transparent"
                        Rectangle {
                            anchors.centerIn: parent
                            width: parent.width - Theme.space.s * 2
                            height: 1
                            color: Theme.border
                        }
                    }
                }

                Component {
                    id: row
                    MenuRow {
                        readonly property var entry: entryLoader.modelData
                        label: entry.text
                        iconSource: entry.icon
                        enabled: entry.enabled
                        checkable: entry.buttonType !== QsMenuButtonType.None
                        checked: entry.checkState === Qt.Checked
                        hasChildren: entry.hasChildren
                        onClicked: {
                            if (entry.hasChildren) {
                                root.stack = [...root.stack, entry];
                            } else {
                                entry.triggered();
                                root.close();
                            }
                        }
                    }
                }
            }
        }
    }

    component MenuRow: MouseArea {
        id: menuRow

        property string label
        property string iconSource
        property string iconName
        property bool checkable: false
        property bool checked: false
        property bool hasChildren: false

        Layout.fillWidth: true
        implicitHeight: 32
        hoverEnabled: true
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor

        Rectangle {
            anchors.fill: parent
            radius: Theme.radius.s
            color: menuRow.enabled && menuRow.containsMouse ? Theme.hover : "transparent"
            Behavior on color {
                ColorAnimation { duration: Theme.anim.fast }
            }
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Theme.space.s
            anchors.rightMargin: Theme.space.s
            spacing: Theme.space.s

            Icon {
                visible: menuRow.checkable
                name: menuRow.checked ? "check_box" : "check_box_outline_blank"
                fill: menuRow.checked ? 1 : 0
                color: menuRow.checked ? Theme.accent : Theme.fgMuted
                size: 16
            }
            Icon {
                visible: menuRow.iconName !== ""
                name: menuRow.iconName
                size: 16
            }
            IconImage {
                visible: menuRow.iconSource !== "" && !menuRow.checkable
                source: menuRow.iconSource
                implicitSize: 16
            }
            StyledText {
                Layout.fillWidth: true
                text: menuRow.label.replace(/_(?!_)/g, "")   // strip mnemonic underscores
                color: menuRow.enabled ? Theme.fg : Theme.fgDisabled
            }
            Icon {
                visible: menuRow.hasChildren
                name: "chevron_right"
                size: 16
                color: Theme.fgMuted
            }
        }
    }
}
