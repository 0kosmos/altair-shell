// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import qs.components
import qs.services
import qs.theme

// Output volume. Scroll to change (5% steps), click to mute.
BarButton {
    visible: Audio.available

    onClicked: Audio.toggleMute()
    onStepped: dir => Audio.changeVolume(dir * 0.05)

    Icon {
        name: Audio.muted || Audio.volume < 0.005 ? "volume_off"
            : Audio.volume < 0.34 ? "volume_mute"
            : Audio.volume < 0.67 ? "volume_down" : "volume_up"
        color: Audio.muted ? Theme.fgDisabled : Theme.fg
    }
    StyledText {
        text: Math.round(Audio.volume * 100) + "%"
        color: Audio.muted ? Theme.fgDisabled : Theme.fg
        font.pixelSize: Theme.font.small
        tabular: true
    }
}
