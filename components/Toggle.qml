// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import qs.services
import qs.theme

// On/off switch. Doesn't change `checked` itself: bind `checked` to the setting
// and write the setting in onToggled, so the switch always shows the truth.
// Motion: the knob slides, and stretches a little while pressed.
MouseArea {
    id: root

    property bool checked: false
    signal toggled(bool value)

    implicitWidth: 42
    implicitHeight: 24
    hoverEnabled: true
    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
    opacity: enabled ? 1 : 0.4
    onClicked: {
        Sounds.toggled(!checked);
        toggled(!checked);
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.pill(height)
        color: root.checked ? Theme.accent : root.containsMouse ? Qt.alpha(Theme.fg, 0.16) : Theme.pressed
        border.width: 1
        border.color: root.checked ? "transparent" : Theme.border

        Behavior on color {
            ColorAnimation { duration: Theme.anim.normal; easing.type: Theme.anim.easing }
        }
    }

    Rectangle {
        id: knob
        readonly property int size: 18
        // Stretches toward the side it is about to move to while pressed.
        width: root.pressed ? size + 5 : size
        height: size
        radius: Theme.pill(size)
        anchors.verticalCenter: parent.verticalCenter
        x: root.checked ? root.width - width - 3 : 3
        color: root.checked ? Theme.onAccent : Theme.fg

        Behavior on x {
            NumberAnimation { duration: Theme.anim.normal; easing.type: Theme.anim.easingSlide }
        }
        Behavior on width {
            NumberAnimation { duration: Theme.anim.fast; easing.type: Theme.anim.easing }
        }
        Behavior on color {
            ColorAnimation { duration: Theme.anim.normal }
        }
    }
}
