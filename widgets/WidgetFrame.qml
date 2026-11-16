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
//
// Magnetic groups: a Visualizer, Equalizer or Lyrics widget dropped next to a
// Music widget attaches to it; Weather, Clock, Round clock and System attach
// to any widget (and take others themselves): on its top or bottom, and on
// its left or right where the result keeps a sensible size. Widgets
// attached at the
// top/bottom take the Music widget's width, at the left/right its height; an
// attached widget can take another one further out on the same side. The
// group moves as one and looks like one surface (touching sides are square
// and edgeless, and the liquid-glass tint runs over the whole group). While
// dragging near a slot, the result is previewed at once. Dragging an attached
// widget detaches it (with whatever hangs further out).
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

    // ---- Magnetic groups ------------------------------------------------------------
    // "music": attaches only to a Music widget; "any": to any widget; "": not.
    readonly property string attachTo: type?.attach ?? ""
    readonly property bool canAttach: attachTo !== ""
    readonly property var parentFrame: item?.attachedTo ? siblings.find(f => f && f.itemId === item.attachedTo) ?? null : null
    // The side of its parent this widget hangs on.
    readonly property string side: ["top", "left", "right"].indexOf(item?.attachSide) !== -1 ? item.attachSide : "bottom"
    readonly property bool attached: parentFrame !== null && !owning
    // While dragged into a magnet slot: shown as if attached there.
    property var previewParent: null
    property string previewSide: "bottom"
    readonly property bool previewing: owning && previewParent !== null
    // The side of the parent it is joined to ("" = not joined).
    readonly property string joinSide: attached ? side : previewing ? previewSide : ""
    readonly property var joinParent: attached ? parentFrame : previewing ? previewParent : null

    // What is joined to this frame on a side (attached, or being previewed).
    function childOn(sd: string): var {
        if (Widgets.attachHint === itemId && Widgets.attachSideHint === sd)
            return siblings.find(f => f && f.itemId === Widgets.attachChild) ?? null;
        return siblings.find(f => f && f !== frame && f.attached && f.item?.attachedTo === itemId && f.side === sd) ?? null;
    }
    readonly property var childTop: childOn("top")
    readonly property var childBottom: childOn("bottom")
    readonly property var childLeft: childOn("left")
    readonly property var childRight: childOn("right")

    // Sides touching another widget of the group.
    readonly property bool joinedTop: joinSide === "bottom" || childTop !== null
    readonly property bool joinedBottom: joinSide === "top" || childBottom !== null
    readonly property bool joinedLeft: joinSide === "right" || childLeft !== null
    readonly property bool joinedRight: joinSide === "left" || childRight !== null

    // Bounding box of this frame and everything joined further out.
    readonly property rect groupBox: {
        let x0 = x, y0 = y, x1 = x + width, y1 = y + height;
        for (const c of [childTop, childBottom, childLeft, childRight]) {
            if (!c)
                continue;
            const b = c.groupBox;
            x0 = Math.min(x0, b.x); y0 = Math.min(y0, b.y);
            x1 = Math.max(x1, b.x + b.width); y1 = Math.max(y1, b.y + b.height);
        }
        return Qt.rect(x0, y0, x1 - x0, y1 - y0);
    }
    readonly property var groupRoot: joinParent ? joinParent.groupRoot : frame

    // How far the widgets attached to this one (and further out) stick out
    // past it on each side, in px. Built from sizes only (not positions), so
    // positions can use it without a binding loop.
    readonly property var ext: {
        const e = { l: 0, t: 0, r: 0, b: 0 };
        const L = childLeft?.attached ? childLeft : null, R = childRight?.attached ? childRight : null;
        const T = childTop?.attached ? childTop : null, B = childBottom?.attached ? childBottom : null;
        if (L) e.l = L.width + L.ext.l;
        if (R) e.r = R.width + R.ext.r;
        if (T) e.t = T.height + T.ext.t;
        if (B) e.b = B.height + B.ext.b;
        // Top/bottom children are as wide as this one; their own side
        // children stick out sideways (and vice versa).
        for (const c of [T, B]) if (c) { e.l = Math.max(e.l, c.ext.l); e.r = Math.max(e.r, c.ext.r); }
        for (const c of [L, R]) if (c) { e.t = Math.max(e.t, c.ext.t); e.b = Math.max(e.b, c.ext.b); }
        return e;
    }
    // The free part of the screen (minus bar, dock), relative to the monitor.
    readonly property var area: {
        const u = mon?.usable ?? { x: mon.x, y: mon.y, w: mon.w, h: mon.h };
        return { x: u.x - mon.x, y: u.y - mon.y, w: u.w, h: u.h };
    }

    // A dragged widget is pulled into a slot within this distance, and only
    // lets go beyond `magnetRelease`.
    readonly property int magnet: 28
    readonly property int magnetRelease: 48

    // This frame and everything attached further out (not valid targets).
    function subtree(): var {
        const l = [];
        const add = f => {
            if (!f || l.indexOf(f) !== -1)
                return;
            l.push(f);
            for (const c of [f.childTop, f.childBottom, f.childLeft, f.childRight])
                if (c && c.joinParent === f && c !== frame)
                    add(c);
        };
        add(frame);
        return l;
    }

    // Detach, staying put (nudged away from the group so it visibly comes loose).
    function detach(): void {
        const d = 16;
        Widgets.update(itemId, {
            attachedTo: "", attachSide: "bottom", scale: Math.round(s * 100) / 100,
            x: Math.max(0, Math.min(mon.w - width, x + (side === "left" ? -d : side === "right" ? d : 0))),
            y: Math.max(0, Math.min(mon.h - height, y + (side === "top" ? -d : side === "bottom" ? d : 0)))
        });
    }

    // Remove: what hangs further out on the same side moves in to the widget
    // this one hangs on; anything else stays where it is, detached.
    function removeSelf(): void {
        for (const c of [childTop, childBottom, childLeft, childRight]) {
            if (!c || !c.attached)
                continue;
            const passOn = attached && c.side === side;
            Widgets.update(c.itemId, passOn ? { attachedTo: item.attachedTo, attachSide: side }
                : { attachedTo: "", attachSide: "bottom", x: c.x, y: c.y, scale: Math.round(c.s * 100) / 100 });
        }
        Widgets.remove(itemId);
    }

    // Slots `f` offers this widget. A standalone widget offers top and
    // bottom (Visualizer/Equalizer/Lyrics only attach to Music; widgets that
    // only hang on Music never take others), and left/right when it is wide
    // (2:1 or more) or this widget would not grow much there. An attached
    // widget offers only its own side, further out. A slot is skipped if
    // this widget would get too small or too big there.
    function slotsOf(f: var): var {
        let sides;
        if (f.attached) {
            sides = [f.side];
        } else {
            if (f.attachTo === "music" || (attachTo === "music" && f.item?.type !== "music"))
                return [];
            sides = ["top", "bottom", "left", "right"];
        }
        return sides.filter(sd => {
            const sc = scaleIn(f, sd);
            if (sc < 0.45 || sc > 2.5)
                return false;
            if ((sd === "left" || sd === "right") && !f.attached && f.width < f.height * 2 && sc > 1.3)
                return false;
            return true;
        });
    }

    // Where `r` ({ x, y, w, h } relative to the monitor) would attach:
    // { frame, side } for the nearest free slot within `magnet` px (the
    // facing edges close, overlapping sideways), else null. `keep` (the
    // current one) is held until `magnetRelease`.
    function attachTarget(r: var, keep: var): var {
        if (!canAttach)
            return null;
        const mine = subtree();
        const gap = (f, sd) => {
            const ox = Math.min(r.x + r.w, f.x + f.width) - Math.max(r.x, f.x);
            const oy = Math.min(r.y + r.h, f.y + f.height) - Math.max(r.y, f.y);
            switch (sd) {
            case "bottom": return ox > Math.min(r.w, f.width) * 0.3 ? Math.abs(r.y - (f.y + f.height)) : 1e9;
            case "top": return ox > Math.min(r.w, f.width) * 0.3 ? Math.abs(r.y + r.h - f.y) : 1e9;
            case "right": return oy > Math.min(r.h, f.height) * 0.3 ? Math.abs(r.x - (f.x + f.width)) : 1e9;
            default: return oy > Math.min(r.h, f.height) * 0.3 ? Math.abs(r.x + r.w - f.x) : 1e9;
            }
        };
        const free = (f, sd) => {
            const c = f.childOn(sd);
            return !c || c === frame;
        };
        if (keep && mine.indexOf(keep.frame) === -1 && slotsOf(keep.frame).indexOf(keep.side) !== -1
                && free(keep.frame, keep.side) && gap(keep.frame, keep.side) <= magnetRelease)
            return keep;
        let best = null;
        for (const f of siblings) {
            if (!f || mine.indexOf(f) !== -1 || !f.visible)
                continue;
            for (const sd of slotsOf(f)) {
                const d = gap(f, sd);
                if (d <= magnet && free(f, sd) && (!best || d < best.d))
                    best = { frame: f, side: sd, d };
            }
        }
        return best ? { frame: best.frame, side: best.side } : null;
    }

    // Scale and position in the slot `sd` of frame `f`.
    function scaleIn(f: var, sd: string): real {
        return sd === "left" || sd === "right" ? f.height / Math.max(1, base.h) : f.width / Math.max(1, base.w);
    }
    function slotPos(f: var, sd: string, w: real, h: real): point {
        return Qt.point(sd === "left" ? f.x - w : sd === "right" ? f.x + f.width : f.x,
                        sd === "top" ? f.y - h : sd === "bottom" ? f.y + f.height : f.y);
    }

    readonly property var item: Widgets.byId(itemId)
    readonly property var type: Widgets.typeType(item?.type ?? "")
    readonly property bool editing: Widgets.editing

    // ---- Geometry ---------------------------------------------------------------
    // While resizing, `liveScale` is shown and only saved on release.
    property real liveScale: -1
    // Joined (or previewing): as wide/tall as the widget it hangs on; the
    // preview grows/shrinks to that smoothly.
    readonly property real targetScale: joinParent ? scaleIn(joinParent, joinSide)
        : liveScale > 0 ? liveScale : Math.max(0.5, Math.min(2.5, item?.scale ?? 1))
    property bool animateScale: false
    property real s: targetScale
    Behavior on s {
        enabled: frame.animateScale
        NumberAnimation { duration: Theme.anim.normal; easing.type: Theme.anim.easingSlide }
    }
    // Base size (depends on the style), then scaled.
    // A widget can ask for a different size than its style's (fitW / fitH,
    // e.g. the system widget without its GPU row); the frame glides there.
    readonly property var styleSize: Widgets.sizeOf(item)
    readonly property var base: ({
        w: (content.item?.fitW ?? -1) > 0 ? content.item.fitW : styleSize.w,
        h: (content.item?.fitH ?? -1) > 0 ? content.item.fitH : styleSize.h
    })
    property real shownW: base.w
    property real shownH: base.h
    Behavior on shownW {
        enabled: frame.settledIn
        NumberAnimation { duration: Theme.anim.slow; easing.type: Easing.OutQuint }
    }
    Behavior on shownH {
        enabled: frame.settledIn
        NumberAnimation { duration: Theme.anim.slow; easing.type: Easing.OutQuint }
    }
    width: Math.round(shownW * s)
    height: Math.round(shownH * s)

    // While this frame is moved, it follows Snap.rect (smooth, also while
    // settling after release); otherwise its saved spot, kept on screen.
    property bool owning: false
    // Resting widgets (with their group) stay inside the free area: when the
    // bar or dock moves over them they glide out of its way (the saved spot
    // is kept, so they come back when it moves away again).
    x: owning && Snap.rect ? Snap.rect.x - mon.x
        : attached ? slotPos(parentFrame, side, width, height).x
        : Math.max(area.x + ext.l, Math.min(area.x + area.w - width - ext.r, item?.x ?? 0))
    y: owning && Snap.rect ? Snap.rect.y - mon.y
        : attached ? slotPos(parentFrame, side, width, height).y
        : Math.max(area.y + ext.t, Math.min(area.y + area.h - height - ext.b, item?.y ?? 0))
    readonly property bool glide: !owning && !attached && !Snap.moving && settledIn
    Behavior on x {
        enabled: frame.glide
        NumberAnimation { duration: Theme.anim.slow; easing.type: Easing.OutQuint }
    }
    Behavior on y {
        enabled: frame.glide
        NumberAnimation { duration: Theme.anim.slow; easing.type: Easing.OutQuint }
    }
    // No glide while the layer is being built.
    property bool settledIn: false
    Component.onCompleted: Qt.callLater(() => frame.settledIn = true)


    readonly property real radius: Theme.radius.l * s
    // The selected widget (and its toolbar) above the others.
    z: Widgets.selected === itemId ? 3 : 0

    // A widget may ask to be hidden outside edit mode (music, when idle).
    visible: editing || !(content.item?.hidden ?? false)

    // Click/blur region of this widget (used by WidgetLayer); empty while
    // hidden, so no blur or click area is left behind.
    // In a group, only the group's outer corners are round.
    readonly property Region region: Region {
        x: frame.x
        y: frame.y
        width: frame.visible ? frame.width : 0
        height: frame.visible ? frame.height : 0
        topLeftRadius: frame.joinedTop || frame.joinedLeft ? 0 : frame.radius
        topRightRadius: frame.joinedTop || frame.joinedRight ? 0 : frame.radius
        bottomLeftRadius: frame.joinedBottom || frame.joinedLeft ? 0 : frame.radius
        bottomRightRadius: frame.joinedBottom || frame.joinedRight ? 0 : frame.radius
    }

    // ---- Look -------------------------------------------------------------------
    // In edit mode never fully invisible, so it can still be grabbed.
    opacity: editing ? Math.max(0.45, item?.opacity ?? 1) : (item?.opacity ?? 1)
    Behavior on opacity {
        NumberAnimation { duration: Theme.anim.fast }
    }

    // Each widget draws its own glass; in a group the touching sides are
    // open (square, edgeless) and the tint runs over the whole group.
    GlassBackground {
        anchors.fill: parent
        radius: frame.radius
        openTop: frame.joinedTop
        openBottom: frame.joinedBottom
        openLeft: frame.joinedLeft
        openRight: frame.joinedRight
        tintOffset: frame.joinParent || frame.childTop || frame.childBottom ? frame.y - frame.groupRoot.groupBox.y : 0
        tintSpan: frame.joinParent || frame.childTop || frame.childBottom ? frame.groupRoot.groupBox.height : 0
    }
    // A hairline on the side joined to the widget it hangs on.
    Rectangle {
        visible: frame.joinSide !== ""
        readonly property bool horizontal: frame.joinSide === "top" || frame.joinSide === "bottom"
        x: horizontal ? 14 * frame.s : frame.joinSide === "right" ? 0 : frame.width - 1
        y: !horizontal ? 14 * frame.s : frame.joinSide === "bottom" ? 0 : frame.height - 1
        width: horizontal ? frame.width - 28 * frame.s : 1
        height: horizontal ? 1 : frame.height - 28 * frame.s
        color: Theme.border
    }

    // The widget, drawn at its base size and scaled (text stays sharp: Qt's
    // default text rendering scales without blurring).
    Loader {
        id: content
        width: frame.shownW
        height: frame.shownH
        scale: frame.s
        transformOrigin: Item.TopLeft
        // Style changes switch the widget's look in place.
        onLoaded: {
            item.style = Qt.binding(() => Widgets.styleOf(frame.item));
            if (item.live !== undefined)
                item.live = Qt.binding(() => frame.live);
            // Where the widget is on its monitor (Weather draws moving effects
            // in a small window of its own there, see WeatherWidget).
            if (item.frameRect !== undefined) {
                item.frameRect = Qt.binding(() => Qt.rect(frame.x, frame.y, frame.width, frame.height));
                item.frameRadius = Qt.binding(() => frame.radius);
                item.screenName = Qt.binding(() => frame.mon.name);
                item.moving = Qt.binding(() => frame.owning || Snap.moving);
            }
        }
        source: {
            switch (frame.item?.type) {
            case "clock": return "ClockWidget.qml";
            case "roundclock": return "RoundClockWidget.qml";
            case "music": return "MusicWidget.qml";
            case "visualizer": return "VisualizerWidget.qml";
            case "eq": return "EqualizerWidget.qml";
            case "weather": return "WeatherWidget.qml";
            case "lyrics": return "LyricsWidget.qml";
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
                // Dragging an attached widget detaches it (keeping its size);
                // it starts out previewed in its old slot, so it only comes
                // loose once pulled away.
                if (frame.attached) {
                    frame.previewParent = frame.parentFrame;
                    frame.previewSide = frame.side;
                    Widgets.attachHint = frame.parentFrame.itemId;
                    Widgets.attachSideHint = frame.side;
                    Widgets.attachChild = frame.itemId;
                    Widgets.update(frame.itemId, { attachedTo: "", attachSide: "bottom", x: frame.x, y: frame.y, scale: Math.round(frame.s * 100) / 100 });
                }
                const mine = frame.subtree();
                const others = frame.siblings.filter(f => f && mine.indexOf(f) === -1 && f.visible)
                    .map(f => ({ x: frame.mon.x + f.x, y: frame.mon.y + f.y, w: f.width, h: f.height }));
                Snap.begin(frame.mon, frame.radius, { x: start.x, y: start.y, w: frame.width, h: frame.height },
                           { targets: others, dim: false, extent: frame.ext });
                frame.owning = true;
            }
            const free = (mouse.modifiers & Qt.ShiftModifier) !== 0;
            // Pointer position at the widget's own (not previewed) size.
            const own = frame.item?.scale ?? frame.s;
            const rw = frame.base.w * own, rh = frame.base.h * own;
            const raw = { x: start.x + p.x - pressAt.x, y: start.y + p.y - pressAt.y, w: frame.width, h: frame.height };
            // Magnet: near a free slot, preview the attached result at once
            // (pulled into the slot, at the group's width or height).
            const keep = frame.previewParent ? { frame: frame.previewParent, side: frame.previewSide } : null;
            const t = free ? null : frame.attachTarget({ x: raw.x - frame.mon.x, y: raw.y - frame.mon.y, w: rw, h: rh }, keep);
            if ((t?.frame ?? null) !== frame.previewParent || (t && t.side !== frame.previewSide)) {
                frame.animateScale = true;
                frame.previewParent = t ? t.frame : null;
                frame.previewSide = t ? t.side : "bottom";
                Widgets.attachChild = t ? frame.itemId : "";
                Widgets.attachHint = t ? t.frame.itemId : "";
                Widgets.attachSideHint = t ? t.side : "";
            }
            if (t) {
                const sc = frame.scaleIn(t.frame, t.side);
                const w = frame.base.w * sc, h = frame.base.h * sc;
                const at = frame.slotPos(t.frame, t.side, w, h);
                Snap.pin = { x: frame.mon.x + at.x, y: frame.mon.y + at.y, w, h };
            } else {
                Snap.pin = null;
            }
            Snap.update(raw, free);
        }
        onReleased: if (start) Snap.end()
        onCanceled: if (start) Snap.end()
    }

    Connections {
        target: Snap
        enabled: frame.owning
        function onSettled(rect) {
            const t = frame.previewParent;
            const r = { x: rect.x - frame.mon.x, y: rect.y - frame.mon.y };
            Widgets.update(frame.itemId, t ? { x: r.x, y: r.y, attachedTo: t.itemId, attachSide: frame.previewSide } : { x: r.x, y: r.y });
            frame.previewParent = null;
            Widgets.attachHint = "";
            Widgets.attachSideHint = "";
            Widgets.attachChild = "";
            frame.owning = false;
            frame.animateScale = false;
        }
    }

    // Resize: drag the bottom-right corner (keeps the proportions). Attached
    // widgets take their size from the widget they hang on instead.
    Item {
        visible: frame.editing && !frame.attached
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
                visible: frame.attached
                icon: "link_off"
                size: 26
                iconSize: 16
                onClicked: frame.detach()
            }
            IconButton {
                icon: "close"
                size: 26
                iconSize: 16
                onClicked: frame.removeSelf()
            }
        }
    }
}
