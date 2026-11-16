// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import qs.components
import qs.theme

// One lyric line that changes smoothly: the old line drifts up and fades
// out while the new one rises in from below. Two text items take turns, so
// nothing is re-laid out during the animation (only opacity and position
// animate, which is cheap).
Item {
    id: root

    property string text
    property int pixelSize: 15
    property int weight: Font.Medium
    property color color: Theme.fg
    property int maximumLineCount: 1
    property int travel: 10

    implicitHeight: Math.max(a.implicitHeight, b.implicitHeight)

    property bool useA: true
    Component.onCompleted: a.text = text
    onTextChanged: {
        if (!Theme.animations) {
            (useA ? a : b).text = text;
            return;
        }
        useA = !useA;
        const inc = useA ? a : b;
        inc.text = text;
    }

    component Line: StyledText {
        id: line
        required property bool active
        width: root.width
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: shift
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        elide: Text.ElideRight
        maximumLineCount: root.maximumLineCount
        font.pixelSize: root.pixelSize
        font.weight: root.weight
        color: root.color
        opacity: active ? 1 : 0
        property real shift: 0
        Behavior on opacity {
            NumberAnimation { duration: Theme.anim.slow; easing.type: Easing.OutCubic }
        }
        // In: from below up to its place. Out: drifting up.
        NumberAnimation { id: slideIn; target: line; property: "shift"; from: root.travel; to: 0; duration: Theme.anim.slow; easing.type: Easing.OutQuint }
        NumberAnimation { id: slideOut; target: line; property: "shift"; to: -root.travel; duration: Theme.anim.slow; easing.type: Easing.OutCubic }
        onActiveChanged: {
            if (!Theme.animations) {
                shift = 0;
                return;
            }
            if (active) {
                slideOut.stop();
                slideIn.restart();
            } else {
                slideIn.stop();
                slideOut.restart();
            }
        }
    }

    Line { id: a; active: root.useA }
    Line { id: b; active: !root.useA }
}
