// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import qs.components
import qs.services
import qs.theme

// Lyrics of the playing track (services/Lyrics.qml, LRCLIB). Styles (sizes
// in services/Widgets.qml):
//   scroll   several lines; the current one highlighted, gliding to the middle
//   focus    the current line large, the next one faint below
//   minimal  just the current line (fits under a Music widget)
// Attaches to a Music widget like the Visualizer and Equalizer.
Item {
    id: root
    property string style: "scroll"

    Component.onCompleted: Lyrics.users++
    Component.onDestruction: Lyrics.users--

    readonly property bool synced: Lyrics.status === "synced"
    readonly property bool hasText: Lyrics.status === "synced" || Lyrics.status === "plain"
    // The current line's text ("♪" for an empty, instrumental line).
    function textAt(i: int): string {
        const l = Lyrics.lines[i];
        return l ? (l.text || "♪") : "";
    }

    // ---- States without lyrics -------------------------------------------------------
    StyledText {
        anchors.centerIn: parent
        width: parent.width - 32
        horizontalAlignment: Text.AlignHCenter
        visible: !root.hasText
        text: !Media.hasTrack ? "Nothing playing"
            : Lyrics.status === "loading" ? "Looking for lyrics…"
            : Lyrics.status === "instrumental" ? "♪  Instrumental"
            : Lyrics.status === "error" ? "Lyrics unavailable"
            : "No lyrics found"
        color: Theme.fgMuted
        font.pixelSize: Theme.font.small
    }

    // Unsynced lyrics: the line is only estimated from the song's progress.
    StyledText {
        visible: Lyrics.estimated && root.style !== "minimal"
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 6
        anchors.rightMargin: 10
        text: "Not synced · estimated"
        color: Theme.fgDisabled
        font.pixelSize: 10
        z: 1
    }

    // ---- Scroll ----------------------------------------------------------------------
    ListView {
        id: list
        anchors.fill: parent
        anchors.margins: 14
        visible: root.style === "scroll" && root.hasText
        clip: true
        interactive: false
        model: root.style === "scroll" && root.hasText ? Lyrics.lines : []
        currentIndex: Lyrics.index
        // Keep the current line in the middle, gliding there.
        highlightRangeMode: ListView.StrictlyEnforceRange
        preferredHighlightBegin: height / 2 - 14
        preferredHighlightEnd: height / 2 + 14
        highlightMoveDuration: Theme.anim.slow
        spacing: 6

        delegate: StyledText {
            required property var modelData
            required property int index
            readonly property bool current: index === Lyrics.index
            width: ListView.view.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            elide: Text.ElideNone
            text: modelData.text || "♪"
            font.pixelSize: current ? 17 : 14
            font.weight: current ? Font.DemiBold : Font.Normal
            color: current ? (Lyrics.estimated ? Theme.fgMuted : Theme.fg) : Theme.fgDisabled
            Behavior on font.pixelSize {
                NumberAnimation { duration: Theme.anim.normal; easing.type: Theme.anim.easing }
            }
        }
    }
    // Soft fade at the top and bottom of the list.
    Rectangle {
        visible: list.visible
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 14
        height: 26
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.alpha(Theme.base, 0.55) }
            GradientStop { position: 1; color: "transparent" }
        }
    }

    // ---- Focus -----------------------------------------------------------------------
    Item {
        anchors.fill: parent
        anchors.margins: 16
        visible: root.style === "focus" && root.hasText

        StyledText {
            id: now
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -10
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            elide: Text.ElideNone
            maximumLineCount: 2
            text: root.textAt(Math.max(0, Lyrics.index))
            font.pixelSize: 22
            font.weight: Font.DemiBold
            // Crossfade on every new line.
            onTextChanged: fade.restart()
            SequentialAnimation {
                id: fade
                NumberAnimation { target: now; property: "opacity"; from: 0.2; to: 1; duration: Theme.anim.normal; easing.type: Theme.anim.easing }
            }
        }
        StyledText {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: now.bottom
            anchors.topMargin: 8
            horizontalAlignment: Text.AlignHCenter
            text: root.textAt(Math.max(0, Lyrics.index) + 1)
            color: Theme.fgDisabled
            font.pixelSize: 14
        }
    }

    // ---- Minimal ---------------------------------------------------------------------
    StyledText {
        id: one
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        visible: root.style === "minimal" && root.hasText
        horizontalAlignment: Text.AlignHCenter
        text: root.textAt(Math.max(0, Lyrics.index))
        font.pixelSize: 15
        font.weight: Font.Medium
        onTextChanged: oneFade.restart()
        NumberAnimation { id: oneFade; target: one; property: "opacity"; from: 0.2; to: 1; duration: Theme.anim.normal; easing.type: Theme.anim.easing }
    }
}
