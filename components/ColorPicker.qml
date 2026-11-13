// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Layouts
import qs.theme

// Visual colour picker: a saturation/brightness field, a hue bar, a preview
// and a hex field.
//
// Works in HSV internally so the hue is kept even for greys/white (where it
// can't be derived from the colour). `changed(color, final)` fires while
// dragging (final = false) and once on release or Enter (final = true).
ColumnLayout {
    id: root

    property real hue: 0.6
    property real sat: 0.5
    property real val: 0.9
    readonly property color color: Qt.hsva(hue, sat, val, 1)

    signal changed(color value, bool final)

    // Start from an existing colour (call when the picker opens).
    function load(c: color): void {
        // Keep the current hue for colours without one (grey/white/black).
        if (c.hsvSaturation > 0.01 && c.hsvHue >= 0)
            hue = c.hsvHue;
        sat = c.hsvSaturation;
        val = c.hsvValue;
    }

    function hex(c: color): string {
        const h = v => Math.round(v * 255).toString(16).padStart(2, "0");
        return "#" + h(c.r) + h(c.g) + h(c.b);
    }

    spacing: Theme.space.m

    // ---- Saturation (x) / brightness (y) field --------------------------------
    Item {
        Layout.fillWidth: true
        implicitHeight: 150

        Rectangle {
            id: field
            anchors.fill: parent
            radius: Theme.radius.m
            // White -> pure hue, left to right ...
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: "#ffffff" }
                GradientStop { position: 1; color: Qt.hsva(root.hue, 1, 1, 1) }
            }
            // ... then transparent -> black, top to bottom.
            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                gradient: Gradient {
                    GradientStop { position: 0; color: "transparent" }
                    GradientStop { position: 1; color: "#000000" }
                }
            }
            border.width: 1
            border.color: Theme.border
        }

        // Handle.
        Rectangle {
            width: fieldArea.pressed ? 22 : 18
            height: width
            radius: width / 2
            x: root.sat * field.width - width / 2
            y: (1 - root.val) * field.height - height / 2
            color: root.color
            border.width: 3
            border.color: "#ffffff"

            Behavior on width {
                NumberAnimation { duration: Theme.anim.fast; easing.type: Easing.OutBack; easing.overshoot: 2 }
            }
            // A thin dark outline so the white ring is visible on light colours.
            Rectangle {
                anchors.fill: parent
                anchors.margins: -1
                radius: width / 2
                color: "transparent"
                border.width: 1
                border.color: Qt.rgba(0, 0, 0, 0.35)
            }
        }

        MouseArea {
            id: fieldArea
            anchors.fill: parent
            // Keep the drag: the settings page scrolls, and would otherwise
            // take over a vertical drag halfway through.
            preventStealing: true
            cursorShape: Qt.CrossCursor
            function set(mouse): void {
                root.sat = Math.max(0, Math.min(1, mouse.x / width));
                root.val = 1 - Math.max(0, Math.min(1, mouse.y / height));
                root.changed(root.color, false);
            }
            onPressed: mouse => set(mouse)
            onPositionChanged: mouse => set(mouse)
            onReleased: root.changed(root.color, true)
        }
    }

    // ---- Hue bar ---------------------------------------------------------------
    Item {
        Layout.fillWidth: true
        implicitHeight: 20

        Rectangle {
            id: hueBar
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: 12
            radius: 6
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0 / 6; color: "#ff0000" }
                GradientStop { position: 1 / 6; color: "#ffff00" }
                GradientStop { position: 2 / 6; color: "#00ff00" }
                GradientStop { position: 3 / 6; color: "#00ffff" }
                GradientStop { position: 4 / 6; color: "#0000ff" }
                GradientStop { position: 5 / 6; color: "#ff00ff" }
                GradientStop { position: 6 / 6; color: "#ff0000" }
            }
        }

        Rectangle {
            width: hueArea.pressed ? 22 : 18
            height: width
            radius: width / 2
            anchors.verticalCenter: parent.verticalCenter
            x: root.hue * hueBar.width - width / 2
            color: Qt.hsva(root.hue, 1, 1, 1)
            border.width: 3
            border.color: "#ffffff"

            Behavior on width {
                NumberAnimation { duration: Theme.anim.fast; easing.type: Easing.OutBack; easing.overshoot: 2 }
            }
        }

        MouseArea {
            id: hueArea
            anchors.fill: parent
            anchors.margins: -4
            // Keep the drag: the settings page scrolls, and would otherwise
            // take over a vertical drag halfway through.
            preventStealing: true
            cursorShape: Qt.PointingHandCursor
            function set(mouse): void {
                root.hue = Math.max(0, Math.min(0.999, (mouse.x - 4) / hueBar.width));
                root.changed(root.color, false);
            }
            onPressed: mouse => set(mouse)
            onPositionChanged: mouse => set(mouse)
            onReleased: root.changed(root.color, true)
        }
    }

    // ---- Preview + hex -----------------------------------------------------------
    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.space.m

        Rectangle {
            implicitWidth: 32
            implicitHeight: 32
            radius: 16
            color: root.color
            border.width: 1
            border.color: Theme.border
        }

        Rectangle {
            implicitWidth: 110
            implicitHeight: 32
            radius: Theme.radius.s
            color: Theme.pressed
            border.width: 1
            border.color: hexInput.activeFocus ? Theme.accent : Theme.border

            TextInput {
                id: hexInput
                anchors.fill: parent
                anchors.leftMargin: Theme.space.s
                verticalAlignment: TextInput.AlignVCenter
                color: /^#?[0-9a-fA-F]{6}$/.test(text) ? Theme.fg : Theme.critical
                font.family: Theme.font.family
                font.pixelSize: Theme.font.body
                maximumLength: 7
                selectByMouse: true
                onAccepted: {
                    const t = text.startsWith("#") ? text : "#" + text;
                    if (/^#[0-9a-fA-F]{6}$/.test(t)) {
                        root.load(t);
                        root.changed(root.color, true);
                        focus = false;
                    }
                }

                // Follows the picker, except while the user is typing.
                Binding on text {
                    when: !hexInput.activeFocus
                    value: root.hex(root.color)
                    restoreMode: Binding.RestoreNone
                }
            }
        }

        StyledText {
            Layout.fillWidth: true
            text: "Drag to pick, or type a hex code and press Enter."
            color: Theme.fgMuted
            font.pixelSize: Theme.font.small
            wrapMode: Text.Wrap
        }
    }
}
