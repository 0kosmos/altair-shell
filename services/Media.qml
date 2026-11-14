// SPDX-License-Identifier: GPL-3.0-or-later
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Mpris

// The media player to show (MPRIS, event-driven, no polling): the one that
// is playing; else the one that played last; else the first one.
Singleton {
    id: root

    readonly property var players: Mpris.players.values
    property var lastActive: null
    readonly property var player: players.find(p => p.isPlaying)
        ?? (players.indexOf(lastActive) !== -1 ? lastActive : null)
        ?? players[0] ?? null
    onPlayerChanged: if (player?.isPlaying) lastActive = player

    readonly property bool playing: player?.isPlaying ?? false
    readonly property bool hasTrack: !!player && (player.trackTitle ?? "") !== ""
}
