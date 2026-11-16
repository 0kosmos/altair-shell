// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import qs.services
import qs.theme

// Horizontal slider with steps. Like Toggle, it reports changes (`moved`)
// instead of changing `value` itself.
//
// Motion: while dragging, the knob follows the pointer continuously (no
// jumping between steps); `moved` fires whenever the snapped step changes, so
// the setting updates live. On release the knob glides onto the step.
// Clicking the track glides there too. Wheel and Left/Right keys step it.
Item {
    id: root

    property real value: 0
    property real from: 0
    property real to: 10
    property real stepSize: 1
    property bool showTicks: true
    signal moved(real value)

    implicitWidth: 200
    implicitHeight: 24
    activeFocusOnTab: true
    opacity: enabled ? 1 : 0.4

    readonly property real ratio: (Math.max(from, Math.min(to, value)) - from) / (to - from)
    readonly property real travel: width - knob.width
    // Knob position: the pointer while dragging, the value otherwise.
    property real dragX: 0
    readonly property real knobX: area.dragging ? dragX : ratio * travel

    function snap(v: real): real {
        const s = Math.round((v - from) / stepSize) * stepSize + from;
        return Math.max(from, Math.min(to, s));
    }
    function valueAt(x: real): real {
        return snap(from + Math.max(0, Math.min(1, x / travel)) * (to - from));
    }
    function report(v: real): void {
        if (v !== value) {
            Sounds.slide((v - from) / (to - from));   // a tick per step, pitch follows the value
            moved(v);
        }
    }

    Keys.onLeftPressed: report(snap(value - stepSize))
    Keys.onRightPressed: report(snap(value + stepSize))

    // Track.
    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        x: knob.width / 2
        width: root.travel
        height: 4
        radius: 2
        color: Theme.pressed

        // Step marks.
        Repeater {
            model: root.showTicks ? Math.round((root.to - root.from) / root.stepSize) + 1 : 0
            Rectangle {
                required property int index
                x: index / (root.to - root.from) * root.stepSize * parent.width - width / 2
                anchors.verticalCenter: parent.verticalCenter
                width: 2
                height: 2
                radius: 1
                color: Theme.fgDisabled
            }
        }

        // Filled part, up to the knob.
        Rectangle {
            width: knob.x
            height: parent.height
            radius: 2
            color: Theme.accent
            Behavior on color {
                ColorAnimation { duration: Theme.anim.normal }
            }
        }
    }

    Rectangle {
        id: knob
        width: 18
        height: 18
        radius: Theme.pill(18)
        anchors.verticalCenter: parent.verticalCenter
        x: root.knobX
        color: Theme.fg
        border.width: root.activeFocus ? 2 : 0
        border.color: Theme.accent
        scale: area.pressed ? 1.2 : area.containsMouse ? 1.1 : 1

        // Glide onto the step after release / click / wheel; follow the
        // pointer exactly while dragging.
        Behavior on x {
            enabled: !area.dragging
            NumberAnimation { duration: Theme.anim.normal; easing.type: Theme.anim.easingSlide }
        }
        Behavior on scale {
            NumberAnimation { duration: Theme.anim.fast; easing.type: Easing.OutBack; easing.overshoot: 2 }
        }
    }

    MouseArea {
        id: area

        property bool dragging: false
        property real grabOffset: 0

        anchors.fill: parent
        anchors.margins: -6
        hoverEnabled: true
        // Keep the drag even if a scrolling parent (settings page) wants it.
        preventStealing: true
        cursorShape: Qt.PointingHandCursor

        // Pointer x in slider coordinates, as the knob's left edge.
        function knobLeft(mx: real): real {
            return Math.max(0, Math.min(root.travel, mx - 6 - grabOffset));
        }

        onPressed: mouse => {
            root.forceActiveFocus();
            const onKnob = Math.abs(mouse.x - 6 - (knob.x + knob.width / 2)) <= knob.width;
            // Grabbing the knob keeps it under the pointer where it was grabbed;
            // clicking the track centres it on the pointer.
            grabOffset = onKnob ? mouse.x - 6 - knob.x : knob.width / 2;
            root.dragX = knobLeft(mouse.x);
            if (!onKnob)
                root.report(root.valueAt(root.dragX));
        }
        onPositionChanged: mouse => {
            if (!pressed)
                return;
            dragging = true;
            root.dragX = knobLeft(mouse.x);
            root.report(root.valueAt(root.dragX));
        }
        onReleased: dragging = false
        onCanceled: dragging = false
        onWheel: wheel => root.report(root.snap(root.value + (wheel.angleDelta.y > 0 ? 1 : -1) * root.stepSize))
    }
}
