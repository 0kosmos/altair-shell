// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import qs.components
import qs.services
import qs.theme

// One app in the dock: icon, running/focused indicator, name tooltip.
//   left click    start the app, or focus it (again: its next window)
//   middle click  start a new instance
//   right click   menu (windows, app actions, pin, close)
//   drag          reorder pinned apps; drag a running app among the pinned
//                 ones to pin it
// Hover zoom is a scale animation that runs only while the hover changes.
Item {
    id: root

    required property var item          // a DockApps.items entry
    property int iconSize: 44
    property real zoom: 1.2
    property string position: "bottom"
    property bool dragging: false
    property bool busy: false           // some drag or menu is active: no tooltip/zoom

    signal dragStarted()
    signal dragMoved(real delta)
    signal dragEnded()
    signal menuRequested()

    readonly property bool vertical: position !== "bottom"
    readonly property int windowCount: item?.windows?.length ?? 0
    readonly property bool focused: windowCount > 0 && item.windows.indexOf(Hyprland.activeToplevel) !== -1
    readonly property bool urgent: item?.windows?.some(t => t.urgent) ?? false
    readonly property string label: item?.entry?.name || item?.appId || ""

    width: iconSize
    height: iconSize
    z: dragging ? 2 : mouse.containsMouse ? 1 : 0

    // Towards the screen's centre: where zoom and tooltip go.
    readonly property int inX: position === "left" ? 1 : position === "right" ? -1 : 0
    readonly property int inY: position === "bottom" ? -1 : 0

    // ---- Icon ----------------------------------------------------------------
    // Rendered at the zoomed size and scaled down at rest, so it stays sharp
    // when it grows. Grows from the edge side (transformOrigin).
    IconImage {
        id: icon
        anchors.centerIn: parent
        implicitSize: Math.round(root.iconSize * root.zoom)
        source: Quickshell.iconPath(root.item?.entry?.icon || root.item?.appId || "", "application-x-executable")
        mipmap: true
        asynchronous: true
        opacity: root.dragging ? 0.85 : 1

        readonly property bool big: (mouse.containsMouse && !root.busy) || root.dragging
        scale: (big ? 1 : 1 / root.zoom) * (mouse.pressed && !root.dragging ? Theme.anim.pressScale : 1) * bounce.factor
        transformOrigin: root.position === "left" ? Item.Left : root.position === "right" ? Item.Right : Item.Bottom
        Behavior on scale {
            NumberAnimation { duration: Theme.anim.fast; easing.type: Theme.anim.easing }
        }
        // Small nudge toward the centre while zoomed.
        transform: Translate {
            x: icon.big ? root.inX * 3 : 0
            y: icon.big ? root.inY * 3 : 0
            Behavior on x { NumberAnimation { duration: Theme.anim.fast; easing.type: Theme.anim.easing } }
            Behavior on y { NumberAnimation { duration: Theme.anim.fast; easing.type: Theme.anim.easing } }
        }
    }

    // One short bounce when an app is started from the dock.
    QtObject {
        id: bounce
        property real factor: 1
    }
    SequentialAnimation {
        id: bounceAnim
        NumberAnimation { target: bounce; property: "factor"; to: 0.82; duration: 110; easing.type: Easing.OutQuad }
        NumberAnimation { target: bounce; property: "factor"; to: 1; duration: 380; easing.type: Easing.OutBack; easing.overshoot: 2.2 }
    }
    function launched(): void {
        if (Theme.animations)
            bounceAnim.restart();
    }

    // ---- Indicator (edge side) ------------------------------------------------
    // Dot = running, two dots = several windows, accent pill = focused,
    // red = a window wants attention.
    Row {
        id: dots
        visible: root.windowCount > 0
        spacing: 3
        rotation: root.vertical ? 90 : 0
        readonly property real edgeOffset: root.iconSize / 2 + 4
        x: (root.width - width) / 2 + (root.position === "left" ? -edgeOffset : root.position === "right" ? edgeOffset : 0)
        y: (root.height - height) / 2 + (root.vertical ? 0 : edgeOffset)

        Repeater {
            model: root.focused ? 1 : Math.min(2, root.windowCount)
            Rectangle {
                width: root.focused ? 14 : 4
                height: 4
                radius: 2
                color: root.urgent ? Theme.critical : root.focused ? Theme.accent : Theme.fgMuted
                Behavior on width { NumberAnimation { duration: Theme.anim.fast; easing.type: Theme.anim.easing } }
                Behavior on color { ColorAnimation { duration: Theme.anim.fast } }
            }
        }
    }

    // ---- Tooltip ----------------------------------------------------------------
    Item {
        id: tip
        readonly property bool show: mouse.containsMouse && !root.busy && !mouse.pressed
        opacity: show ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: Theme.anim.fast; easing.type: Theme.anim.easing } }

        width: tipText.implicitWidth + Theme.space.m * 2
        height: tipText.implicitHeight + Theme.space.xs * 2
        readonly property real reach: root.iconSize / 2 + root.iconSize * (root.zoom - 1) + 10
        x: root.vertical ? (root.inX > 0 ? root.width / 2 + reach : root.width / 2 - reach - width) : (root.width - width) / 2
        y: root.vertical ? (root.height - height) / 2 : root.height / 2 - reach - height

        GlassBackground {
            anchors.fill: parent
            radius: Theme.radius.s
            solidity: 0.6     // no blur behind this one
        }
        StyledText {
            id: tipText
            anchors.centerIn: parent
            text: root.label + (root.windowCount > 1 ? "  ·  " + root.windowCount : "")
            font.pixelSize: Theme.font.small
        }
    }

    // ---- Input -------------------------------------------------------------------
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        cursorShape: root.dragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor
        // Keep the drag after the pointer leaves the icon.
        preventStealing: true

        property real pressAlong: 0
        property bool moved: false
        readonly property bool canDrag: !!root.item?.entry

        function along(m): real {
            return root.vertical ? mapToItem(root.parent, m.x, m.y).y : mapToItem(root.parent, m.x, m.y).x;
        }

        onPressed: m => {
            pressAlong = along(m);
            moved = false;
        }
        onPositionChanged: m => {
            if (!pressed || pressedButtons !== Qt.LeftButton || !canDrag)
                return;
            const d = along(m) - pressAlong;
            if (!moved && Math.abs(d) > 6) {
                moved = true;
                root.dragStarted();
            }
            if (moved)
                root.dragMoved(d);
        }
        onReleased: m => {
            if (moved) {
                moved = false;
                root.dragEnded();
                return;
            }
            if (!containsMouse)
                return;
            if (m.button === Qt.RightButton) {
                root.menuRequested();
            } else if (m.button === Qt.MiddleButton) {
                if (root.item.entry) {
                    DockApps.launch(root.item);
                    root.launched();
                }
            } else {
                if (root.windowCount === 0)
                    root.launched();
                DockApps.activate(root.item);
            }
        }
        onCanceled: {
            if (moved) {
                moved = false;
                root.dragEnded();
            }
        }
    }
}
