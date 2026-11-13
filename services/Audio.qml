// SPDX-License-Identifier: GPL-3.0-or-later
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

// Default output device (PipeWire sink): volume and mute.
Singleton {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property bool available: sink !== null && sink.ready && sink.audio !== null

    // 0.0 – 1.0 (PipeWire allows more; we cap user changes at 100%).
    readonly property real volume: available ? sink.audio.volume : 0
    readonly property bool muted: available ? sink.audio.muted : false

    function setVolume(value: real): void {
        if (!available)
            return;
        // Snap to whole percent so repeated scrolling doesn't drift (0.39999...).
        sink.audio.volume = Math.round(Math.max(0, Math.min(1, value)) * 100) / 100;
        if (sink.audio.muted && value > 0)
            sink.audio.muted = false;
    }

    function changeVolume(delta: real): void {
        setVolume(volume + delta);
    }

    function toggleMute(): void {
        if (available)
            sink.audio.muted = !sink.audio.muted;
    }

    // A node's properties (volume, mute) are only kept up to date while the
    // node is bound by a tracker.
    PwObjectTracker {
        objects: root.sink ? [root.sink] : []
    }
}
