// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import qs.components
import qs.services
import qs.theme

// Lyrics of the playing track (services/Lyrics.qml, LRCLIB). Styles (sizes
// in services/Widgets.qml):
//   scroll   several lines; the current one highlighted, gliding to the middle
//   focus    the current line large, the next one faint below
//   karaoke  the current line in grey, filling with white as it is sung,
//            the next one faint below (synced lyrics; plain ones: no fill)
//   minimal  just the current line (fits under a Music widget)
// Attaches to a Music widget like the Visualizer and Equalizer.
//
// The karaoke fill moves all the time, so while it is visible it is drawn in
// a small window of its own over the widget (FrameOverlay, ~30 fps); in edit
// mode, while dragged or covered, the widget shows a still copy itself.
Item {
    id: root
    property string style: "scroll"
    property bool live: true
    // Set by WidgetFrame (see FrameOverlay).
    property rect frameRect
    property real frameRadius: Theme.radius.l
    property string screenName: ""
    property bool moving: false

    Component.onCompleted: Lyrics.users++
    Component.onDestruction: Lyrics.users--

    readonly property bool synced: Lyrics.status === "synced"
    readonly property bool hasText: Lyrics.status === "synced" || Lyrics.status === "plain"
    // The current line's text ("♪" for an empty, instrumental line).
    function textAt(i: int): string {
        const l = Lyrics.lines[i];
        return l ? (l.text || "♪") : "";
    }
    // Before the first line is sung (index -1): show it, dimmed, as upcoming.
    readonly property int shownIndex: Math.max(0, Lyrics.index)
    readonly property bool upcoming: Lyrics.index < 0

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
        currentIndex: root.shownIndex
        // Keep the current line in the middle, gliding there.
        highlightRangeMode: ListView.StrictlyEnforceRange
        preferredHighlightBegin: height / 2 - 14
        preferredHighlightEnd: height / 2 + 14
        // Glide by duration (not by speed), eased, so every line change
        // takes the same calm time.
        highlightMoveVelocity: -1
        highlightMoveDuration: Theme.animations ? 520 : 0
        spacing: 6

        // All lines share one size (no re-layout while changing); the
        // current one is scaled up and brightened smoothly instead.
        delegate: StyledText {
            required property var modelData
            required property int index
            readonly property bool current: index === Lyrics.index
            readonly property int dist: Math.abs(index - Lyrics.index)
            width: ListView.view.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            elide: Text.ElideNone
            text: modelData.text || "♪"
            font.pixelSize: 16
            font.weight: Font.DemiBold
            color: Lyrics.estimated && current ? Theme.fgMuted : Theme.fg
            scale: current ? 1.06 : 0.9
            opacity: current ? 1 : dist === 1 ? 0.45 : 0.28
            Behavior on scale {
                NumberAnimation { duration: Theme.anim.slow; easing.type: Easing.OutQuint }
            }
            Behavior on opacity {
                NumberAnimation { duration: Theme.anim.slow; easing.type: Easing.OutCubic }
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

        LyricLine {
            id: now
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -12
            height: 60
            maximumLineCount: 2
            text: root.textAt(root.shownIndex)
            pixelSize: 22
            weight: Font.DemiBold
            color: Lyrics.estimated || root.upcoming ? Theme.fgMuted : Theme.fg
        }
        StyledText {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: now.bottom
            anchors.topMargin: 2
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            text: root.textAt(root.shownIndex + 1)
            color: Theme.fgDisabled
            font.pixelSize: 14
            // The next line fades in after the current one has moved.
            onTextChanged: if (Theme.animations) nextFade.restart()
            NumberAnimation on opacity { id: nextFade; from: 0; to: 1; duration: Theme.anim.slow * 1.4; easing.type: Easing.InOutCubic }
        }
    }

    // ---- Minimal ---------------------------------------------------------------------
    LyricLine {
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        visible: root.style === "minimal" && root.hasText
        text: root.textAt(root.shownIndex)
        color: root.upcoming ? Theme.fgMuted : Theme.fg
        pixelSize: 15
        weight: Font.Medium
        travel: 8
    }

    // ---- Karaoke ---------------------------------------------------------------------
    // Still copy inside the widget (edit mode, dragging, covered, paused).
    KaraokeView {
        anchors.fill: parent
        visible: root.style === "karaoke" && root.hasText && !overlay.showing
        progress: stillProgress
        // Frozen at the current moment when the overlay hands over.
        property real stillProgress: 1
    }

    // Moving copy in its own window over the widget.
    FrameOverlay {
        id: overlay
        wanted: root.style === "karaoke" && root.hasText && root.synced && root.live
            && Media.playing && Theme.animations
        frameRect: root.frameRect
        screenName: root.screenName
        moving: root.moving
        content: Component {
            Item {
                // Drawn at the widget's base size, scaled like the widget.
                KaraokeView {
                    id: moving
                    width: root.width
                    height: root.height
                    scale: parent.width / Math.max(1, root.width)
                    transformOrigin: Item.TopLeft
                    progress: 0
                    // ~30 fps; only the clip widths change.
                    Timer {
                        interval: 33
                        repeat: true
                        running: true
                        triggeredOnStart: true
                        onTriggered: {
                            const sp = Lyrics.span(Lyrics.index);
                            moving.progress = Math.max(0, Math.min(1, (Lyrics.position() + 0.15 - sp.start) / (sp.end - sp.start)));
                        }
                    }
                }
            }
        }
    }
}
