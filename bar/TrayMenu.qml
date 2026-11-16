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

    // Opens away from the bar: below/above it, or beside a side bar.
    readonly property string pos: Theme.barPosition
    anchor.item: anchorItem
    anchor.rect.x: pos === "left" ? anchorItem.width + gap : pos === "right" ? -gap : 0
    anchor.rect.y: pos === "top" ? anchorItem.height + gap : pos === "bottom" ? -gap : 0
    anchor.rect.width: Theme.barVertical ? 1 : anchorItem.width
    anchor.rect.height: Theme.barVertical ? anchorItem.height : 1
    anchor.edges: pos === "top" ? Edges.Bottom : pos === "bottom" ? Edges.Top : pos === "left" ? (Edges.Right | Edges.Top) : (Edges.Left | Edges.Top)
    anchor.gravity: pos === "top" ? Edges.Bottom : pos === "bottom" ? Edges.Top : pos === "left" ? (Edges.Right | Edges.Bottom) : (Edges.Left | Edges.Bottom)

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

    GlassBackground {
        id: background
        animate: true
        anchors.fill: parent
        radius: Theme.radius.m

        // Open animation: short fade + slide toward the bar.
        opacity: 0
        transform: Translate {
            id: slide
            x: root.pos === "left" ? -6 : root.pos === "right" ? 6 : 0
            y: root.pos === "top" ? -6 : root.pos === "bottom" ? 6 : 0
            Behavior on x {
                NumberAnimation { duration: Theme.anim.fast; easing.type: Theme.anim.easing }
            }
            Behavior on y {
                NumberAnimation { duration: Theme.anim.fast; easing.type: Theme.anim.easing }
            }
        }
        Component.onCompleted: {
            opacity = 1;
            slide.x = 0;
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
        transform: Translate { x: slide.x; y: slide.y }

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
}
