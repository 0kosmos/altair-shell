// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import qs.services
import qs.theme

// Segmented control: pick one of a few options, e.g. Dark | Light.
// options: [{ label, value }]. Reports `selected(value)`; bind `current`.
// Motion: the highlight glides to the new option; labels fade between weights.
Item {
    id: root

    property var options: []
    property var current
    signal selected(var value)

    readonly property int index: options.findIndex(o => o.value === current)
    // All segments are equally wide: wide enough for the longest label plus
    // padding on both sides (at least 84 px).
    readonly property int labelPadding: 16
    // stretch: segments share the width the layout gives (e.g. Layout.fillWidth
    // in a narrow menu) instead of their natural size.
    property bool stretch: false
    readonly property int naturalSegment: {
        void measure.count;   // re-evaluate when the labels change
        let widest = 0;
        for (let i = 0; i < measure.count; i++)
            widest = Math.max(widest, measure.itemAt(i)?.implicitWidth ?? 0);
        return Math.max(stretch ? 40 : 84, Math.ceil(widest) + (stretch ? 20 : labelPadding * 2));
    }
    readonly property real segment: stretch && width > 0 && options.length > 0 ? (width - 4) / options.length : naturalSegment

    // Invisible copies of the labels, only to measure them.
    Repeater {
        id: measure
        model: root.options
        StyledText {
            required property var modelData
            visible: false
            text: modelData.label
            font.pixelSize: Theme.font.small + 1
            font.weight: Font.Medium
        }
    }

    implicitWidth: options.length * naturalSegment + 4
    implicitHeight: 32

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Theme.pressed
        border.width: 1
        border.color: Theme.border
    }

    // Sliding highlight behind the selected option.
    Rectangle {
        visible: root.index >= 0
        x: 2 + Math.max(0, root.index) * root.segment
        y: 2
        width: root.segment
        height: parent.height - 4
        radius: height / 2
        color: Theme.dark ? Qt.lighter(Theme.base, 1.9) : "#ffffff"
        border.width: 1
        border.color: Theme.border

        Behavior on x {
            NumberAnimation { duration: Theme.anim.slow; easing.type: Theme.anim.easingSlide }
        }
    }

    Row {
        x: 2
        y: 2
        Repeater {
            model: root.options

            MouseArea {
                id: option
                required property var modelData
                required property int index
                readonly property bool active: index === root.index

                width: root.segment
                height: root.height - 4
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    Sounds.click();
                    root.selected(modelData.value);
                }

                StyledText {
                    anchors.centerIn: parent
                    text: option.modelData.label
                    font.pixelSize: Theme.font.small + 1
                    font.weight: Font.Medium
                    color: option.active ? Theme.fg : option.containsMouse ? Qt.alpha(Theme.fg, 0.85) : Theme.fgMuted
                    scale: option.pressed ? Theme.anim.pressScale : 1
                    Behavior on scale {
                        NumberAnimation { duration: Theme.anim.fast; easing.type: Easing.OutBack; easing.overshoot: 2.5 }
                    }
                }
            }
        }
    }
}
