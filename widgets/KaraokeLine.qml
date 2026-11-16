// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import qs.components
import qs.theme

// A lyric line in grey that fills with white from left to right as it is
// sung (`progress` 0..1), also across a wrapped second line: each laid-out
// line of the text gets its own clipped white copy, filled in turn. Only
// the clip widths change while it fills (no text re-layout).
Item {
    id: root

    property string text
    property real progress: 0
    property int pixelSize: 22
    property int weight: Font.Bold
    property int maximumLineCount: 2
    property color baseColor: Qt.alpha(Theme.fg, 0.32)
    property color fillColor: Theme.fg

    implicitHeight: base.implicitHeight

    // Geometry of each laid-out line: { x, y, w, h } (x after centring).
    property var lineBoxes: []
    property var pending: []

    StyledText {
        id: base
        width: root.width
        text: root.text
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        elide: Text.ElideRight
        maximumLineCount: root.maximumLineCount
        font.pixelSize: root.pixelSize
        font.weight: root.weight
        color: root.baseColor
        onLineLaidOut: line => {
            if (line.number === 0)
                root.pending = [];
            root.pending.push({ x: (width - line.implicitWidth) / 2, y: line.y, w: line.implicitWidth, h: line.height });
            if (line.isLast || line.number === root.maximumLineCount - 1)
                Qt.callLater(() => root.lineBoxes = root.pending.slice());
        }
    }

    readonly property real total: lineBoxes.reduce((a, b) => a + b.w, 0)

    Repeater {
        model: root.lineBoxes
        Item {
            required property var modelData
            required property int index
            // Width already filled on the lines before this one.
            readonly property real before: root.lineBoxes.slice(0, index).reduce((a, b) => a + b.w, 0)
            readonly property real fill: Math.max(0, Math.min(modelData.w, root.progress * root.total - before))
            x: modelData.x
            y: modelData.y
            width: Math.ceil(fill)
            height: modelData.h + 4
            clip: true
            visible: width > 0

            // The same text in white, positioned so its line lines up.
            StyledText {
                x: -parent.x
                y: -parent.y
                width: root.width
                text: root.text
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                elide: Text.ElideRight
                maximumLineCount: root.maximumLineCount
                font.pixelSize: root.pixelSize
                font.weight: root.weight
                color: root.fillColor
            }
        }
    }
}
