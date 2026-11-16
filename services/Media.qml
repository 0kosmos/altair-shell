// SPDX-License-Identifier: GPL-3.0-or-later
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire

// The media player to show (MPRIS, event-driven, no polling): the one that
// is playing; else the one that played last; else one with a track; else
// the first one.
// Also: where it plays ("Spotify", "SoundCloud · Chrome") and the player's
// own volume (not the system's).
Singleton {
    id: root

    readonly property var players: Mpris.players.values
    property var lastActive: null
    readonly property var player: players.find(p => p.isPlaying)
        ?? (players.indexOf(lastActive) !== -1 ? lastActive : null)
        // One with a track before an empty one (a browser tab registers a
        // player without anything loaded).
        ?? players.find(p => (p.trackTitle ?? "") !== "")
        ?? players[0] ?? null
    onPlayerChanged: if (player?.isPlaying) lastActive = player

    readonly property bool playing: player?.isPlaying ?? false
    readonly property bool hasTrack: !!player && (player.trackTitle ?? "") !== ""

    // ---- Where it plays --------------------------------------------------------------
    // The app's name, shortened ("Google Chrome" -> "Chrome"); for a browser
    // also the site, from the track's URL when the player reports one.
    readonly property string appName: (player?.identity ?? "").replace(/^(Google|Mozilla)\s+/, "")
    readonly property string site: siteOf(String(player?.metadata?.["xesam:url"] ?? "")) ?? ""
    function siteOf(url: string): string {
        const m = url.match(/^https?:\/\/(?:www\.|m\.)?([^/:]+)/i);
        if (!m)
            return "";
        const host = m[1].toLowerCase();
        const known = { "soundcloud.com": "SoundCloud", "youtube.com": "YouTube", "music.youtube.com": "YouTube Music",
            "youtu.be": "YouTube", "open.spotify.com": "Spotify", "twitch.tv": "Twitch", "bandcamp.com": "Bandcamp",
            "deezer.com": "Deezer", "music.apple.com": "Apple Music", "tidal.com": "Tidal", "mixcloud.com": "Mixcloud" };
        if (known[host])
            return known[host];
        // something.bandcamp.com -> Bandcamp; else the domain without its ending.
        const parts = host.split(".");
        const base = parts.length >= 2 ? parts[parts.length - 2] : host;
        return known[parts.slice(-2).join(".")] ?? base.charAt(0).toUpperCase() + base.slice(1);
    }
    readonly property string source: site && site !== appName ? site + " · " + appName : appName

    // ---- The player's own volume -----------------------------------------------------
    // MPRIS volume when the player supports it (Spotify does); else the
    // volume of the app's audio stream in PipeWire (e.g. some browsers).
    readonly property bool mprisVolume: (player?.volumeSupported ?? false) && (player?.canControl ?? false)
    readonly property var stream: mprisVolume ? null : (playerNodes[0] ?? null)

    // The player's audio streams in PipeWire (also used by the visualizer).
    // Quickshell calls playback streams "sinks" (isSink: they play into one),
    // and fills `properties` only for tracked nodes, so all playback streams
    // are tracked (a handful) and matched by node name or app name/binary.
    readonly property var playbackNodes: (Pipewire.nodes?.values ?? []).filter(n => n.isStream && n.isSink)
    PwObjectTracker {
        objects: root.playbackNodes
    }
    readonly property var playerNodes: {
        if (!player)
            return [];
        const names = [player.identity, player.desktopEntry, appName].filter(n => n).map(n => String(n).toLowerCase());
        const like = s => s.length > 2 && names.some(x => s === x || s.includes(x) || x.includes(s));
        return playbackNodes.filter(n => {
            const p = n.properties ?? {};
            return like(String(n.name ?? "").toLowerCase()) || like(String(p["application.name"] ?? "").toLowerCase())
                || like(String(p["application.process.binary"] ?? "").toLowerCase());
        });
    }
    readonly property bool hasVolume: mprisVolume || (stream?.audio ?? null) !== null
    readonly property real volume: mprisVolume ? (player?.volume ?? 0) : (stream?.audio?.volume ?? 0)

    function setVolume(v: real): void {
        v = Math.round(Math.max(0, Math.min(1, v)) * 100) / 100;
        if (mprisVolume)
            player.volume = v;
        else if (stream?.audio)
            stream.audio.volume = v;
    }
}
