// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import Quickshell
import qs.components
import qs.core
import qs.services
import qs.theme

// Screen recording (services/Recorder.qml): click to record the focused
// monitor at 60 fps, click again to stop and save. While recording: a red dot
// and the time, updated once a second.
BarButton {
    id: root
    visible: Config.recorder.showButton
    onClicked: Recorder.toggle()

    property int elapsed: 0
    Timer {
        interval: 1000
        repeat: true
        running: Recorder.recording
        triggeredOnStart: true
        onTriggered: root.elapsed = Math.floor((Date.now() - Recorder.startedAt.getTime()) / 1000)
    }

    Icon {
        visible: !Recorder.recording
        name: "screen_record"
    }
    Rectangle {
        visible: Recorder.recording
        width: 10
        height: 10
        radius: 5
        color: Theme.critical
    }
    StyledText {
        visible: Recorder.recording
        text: Math.floor(root.elapsed / 60) + ":" + String(root.elapsed % 60).padStart(2, "0")
        font.pixelSize: Theme.font.small
        font.weight: Font.DemiBold
        tabular: true
    }
}
