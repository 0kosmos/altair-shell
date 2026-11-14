// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.components
import qs.services
import qs.theme

// One placed widget: position, size (the type's base size × scale), opacity
// and a glass background, with the widget itself inside. In edit mode it also
// gets handles: drag anywhere to move (smooth snapping to the screen and to
// other widgets, services/Snap.qml), drag the corner to resize, a small
// toolbar with an opacity slider and a remove button.
Item {
    id: frame

    required property string itemId
    // This screen as Snap.monitorInfo(): { name, x, y, w, h, usable }.
    required property var mon
    // The other frames on this layer (to snap to).
    property var siblings: []
    // False while windows cover the desktop: the widget pauses animations
    // and polling (see WidgetLayer.covered).
    property bool live: true

    readonly property var item: Widgets.byId(itemId)
    readonly property var type: Widgets.typeType(item?.type ?? "")
    readonly property bool editing: Widgets.editing

    // ---- Geometry ---------------------------------------------------------------
    // While resizing, `liveScale` is shown and only saved on release.
    property real liveScale: -1
    readonly property real s: liveScale > 0 ? liveScale : Math.max(0.5, Math.min(2.5, item?.scale ?? 1))
    // Base size (depends on the style), then scaled.
    readonly property var base: Widgets.sizeOf(item)
    width: Math.round(base.w * s)
    height: Math.round(base.h * s)

    // While this frame is moved, it follows Snap.rect (smooth, also while
    // settling after release); otherwise its saved spot, kept on screen.
    property bool owning: false
    x: owning && Snap.rect ? Snap.rect.x - mon.x
        : Math.max(0, Math.min(mon.w - width, item?.x ?? 0))
    y: owning && Snap.rect ? Snap.rect.y - mon.y
        : Math.max(0, Math.min(mon.h - height, item?.y ?? 0))

    readonly property real radius: Theme.radius.l * s
    // The selected widget (and its toolbar) above the others.
    z: Widgets.selected === itemId ? 1 : 0

    // A widget may ask to be hidden outside edit mode (music, when idle).
    visible: editing || !(content.item?.hidden ?? false)

    // Click/blur region of this widget (used by WidgetLayer); empty while
    // hidden, so no blur or click area is left behind.
    readonly property Region region: Region {
        x: frame.x
        y: frame.y
        width: frame.visible ? frame.width : 0
        height: frame.visible ? frame.height : 0
        radius: frame.radius
    }

    // ---- Look -------------------------------------------------------------------
    // In edit mode never fully invisible, so it can still be grabbed.
    opacity: editing ? Math.max(0.45, item?.opacity ?? 1) : (item?.opacity ?? 1)
    Behavior on opacity {
        NumberAnimation { duration: Theme.anim.fast }
    }

    GlassBackground {
        anchors.fill: parent
        radius: frame.radius
    }

    // The widget, drawn at its base size and scaled (text stays sharp: Qt's
    // default text rendering scales without blurring).
    Loader {
        id: content
        width: frame.base.w
        height: frame.base.h
        scale: frame.s
        transformOrigin: Item.TopLeft
        // Style changes switch the widget's look in place.
        onLoaded: {
            item.style = Qt.binding(() => Widgets.styleOf(frame.item));
            if (item.live !== undefined)
                item.live = Qt.binding(() => frame.live);
        }
        source: {
            switch (frame.item?.type) {
            case "clock": return "ClockWidget.qml";
            case "roundclock": return "RoundClockWidget.qml";
            case "music": return "MusicWidget.qml";
            case "stats": return "StatsWidget.qml";
            default: return "";
            }
        }
    }

    // ---- Edit mode ----------------------------------------------------------------
    Rectangle {
        anchors.fill: parent
        anchors.margins: -2
        visible: frame.editing
        radius: frame.radius + 2
        color: "transparent"
        border.width: 2
        border.color: move.containsMouse || move.pressed || corner.pressed ? Theme.accent : Qt.alpha(Theme.fg, 0.35)
        Behavior on border.color {
            ColorAnimation { duration: Theme.anim.fast }
        }
    }

    // Move: drag anywhere on the widget.
    MouseArea {
        id: move
        anchors.fill: parent
        enabled: frame.editing
        hoverEnabled: true
        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        preventStealing: true

        property point pressAt
        property var start: null

        onPressed: mouse => {
            // Grabbed while still settling from the last drag: start fresh.
            if (frame.owning) {
                Snap.settling = false;
                frame.owning = false;
            }
            pressAt = mapToItem(null, mouse.x, mouse.y);
            start = null;
            Widgets.selected = frame.itemId;
        }
        onPositionChanged: mouse => {
            if (!pressed)
                return;
            const p = mapToItem(null, mouse.x, mouse.y);
            if (!start) {
                if (Math.hypot(p.x - pressAt.x, p.y - pressAt.y) < 4)
                    return;
                start = { x: frame.mon.x + frame.x, y: frame.mon.y + frame.y };
                const others = frame.siblings.filter(f => f && f !== frame)
                    .map(f => ({ x: frame.mon.x + f.x, y: frame.mon.y + f.y, w: f.width, h: f.height }));
                Snap.begin(frame.mon, frame.radius, { x: start.x, y: start.y, w: frame.width, h: frame.height },
                           { targets: others, dim: false });
                frame.owning = true;
            }
            const free = (mouse.modifiers & Qt.ShiftModifier) !== 0;
            Snap.update({ x: start.x + p.x - pressAt.x, y: start.y + p.y - pressAt.y, w: frame.width, h: frame.height }, free);
        }
        onReleased: if (start) Snap.end()
        onCanceled: if (start) Snap.end()
    }

    Connections {
        target: Snap
        enabled: frame.owning
        function onSettled(rect) {
            Widgets.update(frame.itemId, { x: rect.x - frame.mon.x, y: rect.y - frame.mon.y });
            frame.owning = false;
        }
    }

    // Resize: drag the bottom-right corner (keeps the proportions).
    Item {
        visible: frame.editing
        width: 34
        height: 34
        x: frame.width - width / 2 - 4
        y: frame.height - height / 2 - 4

        Rectangle {
            anchors.centerIn: parent
            width: corner.containsMouse || corner.pressed ? 18 : 14
            height: width
            radius: width / 2
            color: Theme.accent
            border.width: 2
            border.color: Theme.base
            Behavior on width {
                NumberAnimation { duration: Theme.anim.fast; easing.type: Theme.anim.easing }
            }
        }

        MouseArea {
            id: corner
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.SizeFDiagCursor
            preventStealing: true

            property real pressX
            property real startW

            onPressed: mouse => {
                Widgets.selected = frame.itemId;
                pressX = mapToItem(null, mouse.x, mouse.y).x;
                startW = frame.width;
                frame.liveScale = frame.s;
            }
            onPositionChanged: mouse => {
                if (!pressed)
                    return;
                const dx = mapToItem(null, mouse.x, mouse.y).x - pressX;
                const t = frame.base.w;
                // Not past the screen's right/bottom edge.
                const maxS = Math.min(2.5, (frame.mon.w - frame.x) / t, (frame.mon.h - frame.y) / frame.base.h);
                frame.liveScale = Math.max(0.5, Math.min(maxS, (startW + dx) / t));
            }
            onReleased: {
                Widgets.update(frame.itemId, { scale: Math.round(frame.liveScale * 100) / 100 });
                frame.liveScale = -1;
            }
            onCanceled: frame.liveScale = -1
        }
    }

    // Toolbar: opacity + remove, for the selected widget (click one to select
    // it). Above the widget, or below it near the top of the screen.
    Rectangle {
        readonly property bool active: frame.editing && Widgets.selected === frame.itemId
        visible: opacity > 0
        opacity: active ? 1 : 0
        Behavior on opacity {
            NumberAnimation { duration: Theme.anim.fast; easing.type: Theme.anim.easing }
        }
        readonly property bool below: frame.y < height + 12
        x: Math.max(-frame.x, Math.min(frame.width - width, (frame.width - width) / 2))
        y: below ? frame.height + 10 : -height - 10
        width: bar.implicitWidth + Theme.space.m * 2
        height: 36
        radius: height / 2
        color: Theme.surfaceRaised
        border.width: 1
        border.color: Theme.border

        RowLayout {
            id: bar
            anchors.centerIn: parent
            spacing: Theme.space.s

            // Style: click to cycle through the type's styles.
            MouseArea {
                id: styleButton
                readonly property var styles: frame.type?.styles ?? []
                visible: styles.length > 1
                implicitWidth: styleRow.implicitWidth + Theme.space.s * 2
                implicitHeight: 26
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Widgets.cycleStyle(frame.itemId)
                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: styleButton.containsMouse ? Theme.hover : "transparent"
                }
                RowLayout {
                    id: styleRow
                    anchors.centerIn: parent
                    spacing: 4
                    Icon {
                        name: "palette"
                        size: 15
                        color: Theme.fgMuted
                    }
                    StyledText {
                        text: styleButton.styles.find(s => s.id === Widgets.styleOf(frame.item))?.name ?? ""
                        font.pixelSize: Theme.font.small
                    }
                }
            }
            Rectangle {
                visible: styleButton.visible
                implicitWidth: 1
                implicitHeight: 18
                color: Theme.border
            }
            Icon {
                name: "opacity"
                size: 16
                color: Theme.fgMuted
            }
            Slider {
                implicitWidth: 110
                from: 20
                to: 100
                stepSize: 5
                showTicks: false
                value: Math.round((frame.item?.opacity ?? 1) * 100)
                onMoved: value => Widgets.update(frame.itemId, { opacity: value / 100 })
            }
            IconButton {
                icon: "close"
                size: 26
                iconSize: 16
                onClicked: Widgets.remove(frame.itemId)
            }
        }
    }
}
