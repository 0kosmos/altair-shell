// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import Quickshell.Widgets
import qs.components
import qs.core
import qs.services
import qs.theme

// A standalone music visualizer (sound bars). Effects = styles: Bars,
// Mirror, Wave, Peaks, Circle (with the album art in the middle). Base size
// 360 x 130 (Circle 240 x 240). Data from cava (services/Cava.qml), which
// only runs while something plays and the desktop isn't covered.
Item {
    id: root
    property string style: "bars"
    property bool live: true        // false while covered by windows (WidgetFrame)
    readonly property bool hidden: !Media.hasTrack && Config.widgets.musicHideIdle

    Visualizer {
        id: vis
        anchors.fill: parent
        anchors.margins: root.style === "circle" ? 10 : 16
        style: root.style
        active: root.live
    }

    // Circle: the album art as the record label in the middle.
    ClippingRectangle {
        visible: root.style === "circle"
        anchors.centerIn: parent
        width: Math.min(vis.width, vis.height) * 0.6 - 10
        height: width
        radius: width / 2
        color: Qt.alpha(Theme.fg, 0.06)
        Icon {
            anchors.centerIn: parent
            visible: art.status !== Image.Ready
            name: "music_note"
            size: Math.round(parent.width * 0.35)
            color: Theme.fgDisabled
        }
        Image {
            id: art
            anchors.fill: parent
            source: Media.player?.trackArtUrl ?? ""
            sourceSize: Qt.size(256, 256)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
        }
    }

    // Nothing playing: a hint under the resting bars.
    StyledText {
        visible: !Media.hasTrack && root.style !== "circle"
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 14
        text: "Nothing playing"
        color: Theme.fgDisabled
        font.pixelSize: Theme.font.small
    }
}
