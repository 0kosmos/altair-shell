// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import qs.services
import qs.theme

// The Lyrics widget's karaoke style (also drawn inside its overlay window):
// the current line in grey filling with white as it is sung (`progress`),
// the next line faint below. A new line slides in while the finished one
// drifts up and fades (two lines take turns).
Item {
    id: kv
    property real progress: 1

    readonly property bool synced: Lyrics.status === "synced"
    readonly property int shownIndex: Math.max(0, Lyrics.index)
    readonly property bool upcoming: Lyrics.index < 0
    function textAt(i: int): string {
        const l = Lyrics.lines[i];
        return l ? (l.text || "♪") : "";
    }

    // Two lines take turns, so a new line slides in while the old
    // (finished, all white) one drifts up and fades.
    property bool useA: true
    property string textA: kv.textAt(kv.shownIndex)
    property string textB: ""
    readonly property int idx: kv.shownIndex
    onIdxChanged: {
        useA = !useA;
        if (useA) textA = kv.textAt(idx); else textB = kv.textAt(idx);
    }
    // New song: start over without the slide.
    Connections {
        target: Lyrics
        function onLinesChanged() {
            kv.useA = true;
            kv.textA = kv.textAt(kv.shownIndex);
            kv.textB = "";
        }
    }

    Item {
        id: stage
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 16
        height: parent.height - 32 - 22

        Repeater {
            model: 2
            KaraokeLine {
                id: kl
                required property int index
                readonly property bool active: (index === 0) === kv.useA
                width: stage.width
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: shift
                text: index === 0 ? kv.textA : kv.textB
                progress: active ? (kv.synced && !kv.upcoming ? kv.progress : 0) : 1
                pixelSize: 22
                opacity: active ? 1 : 0
                property real shift: 0
                Behavior on opacity { NumberAnimation { duration: Theme.anim.slow; easing.type: Easing.OutCubic } }
                NumberAnimation { id: klIn; target: kl; property: "shift"; from: 12; to: 0; duration: Theme.anim.slow; easing.type: Easing.OutQuint }
                NumberAnimation { id: klOut; target: kl; property: "shift"; to: -12; duration: Theme.anim.slow; easing.type: Easing.OutCubic }
                onActiveChanged: {
                    if (!Theme.animations) { shift = 0; return; }
                    if (active) { klOut.stop(); klIn.restart(); } else { klIn.stop(); klOut.restart(); }
                }
            }
        }
    }
    LyricLine {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 14
        height: 22
        text: kv.textAt(kv.shownIndex + 1)
        color: Theme.fgDisabled
        pixelSize: 14
        weight: Font.Normal
        travel: 6
    }
}
