// SPDX-License-Identifier: GPL-3.0-or-later
pragma Singleton

import QtQuick
import Quickshell

// Lyrics for the playing track, time-synced when possible, from LRCLIB
// (lrclib.net: free, open, no account; Spotify's own lyrics are not available
// to other apps). Sent: the track's title, artist, album and length, and only
// while a Lyrics widget exists (`users` > 0). Results are cached in memory.
//
// The current line follows the playback position: MPRIS doesn't push it, so
// it is asked for every 2 s while playing and estimated in between.
Singleton {
    id: root

    property int users: 0
    readonly property var player: Media.player
    readonly property string title: player?.trackTitle ?? ""
    readonly property string artist: player?.trackArtist ?? ""
    readonly property string album: player?.trackAlbum ?? ""
    readonly property real length: player?.length ?? 0      // seconds
    readonly property string key: artist + "\u0001" + title
    readonly property bool wanted: users > 0 && title !== ""

    // "idle" | "loading" | "synced" | "plain" | "instrumental" | "none" | "error"
    property string status: "idle"
    // [{ t: seconds (-1 = unsynced), text }]
    property var lines: []
    property int index: -1          // current line
    readonly property bool hasLines: (status === "synced" || status === "plain") && lines.length > 0
    // Plain (unsynced) lyrics: the current line is only estimated from the
    // song's progress (shown as such).
    readonly property bool estimated: status === "plain"

    property var cache: ({})

    onKeyChanged: if (wanted) load()
    onWantedChanged: if (wanted) load()

    function load(): void {
        index = -1;
        if (!title) {
            status = "idle";
            lines = [];
            return;
        }
        const c = cache[key];
        if (c) {
            apply(c);
            return;
        }
        status = "loading";
        lines = [];
        const k = key;
        const q = "artist_name=" + encodeURIComponent(artist) + "&track_name=" + encodeURIComponent(title)
            + (album ? "&album_name=" + encodeURIComponent(album) : "")
            + (length > 0 ? "&duration=" + Math.round(length) : "");
        request("https://lrclib.net/api/get?" + q, (code, data) => {
            if (code === 200 && data)
                return done(k, data);
            // No exact match (e.g. a different album or length): search.
            request("https://lrclib.net/api/search?artist_name=" + encodeURIComponent(artist) + "&track_name=" + encodeURIComponent(title), (code2, list) => {
                if (code2 !== 200 || !Array.isArray(list))
                    return done(k, code2 === 404 ? {} : null);
                done(k, list.find(r => r.syncedLyrics) ?? list.find(r => r.plainLyrics || r.instrumental) ?? {});
            });
        });
    }

    function request(url: string, cb: var): void {
        const xhr = new XMLHttpRequest();
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return;
            let data = null;
            try {
                data = JSON.parse(xhr.responseText);
            } catch (e) {}
            cb(xhr.status, data);
        };
        xhr.open("GET", url);
        // LRCLIB asks clients to identify themselves.
        xhr.setRequestHeader("Lrclib-Client", "Altair (https://github.com/0kosmos/altair-shell)");
        xhr.send();
    }

    // `data`: an LRCLIB record, {} for "not found", null for an error.
    function done(k: string, data: var): void {
        let result;
        if (data === null)
            result = { status: "error", lines: [] };
        else if (data.instrumental)
            result = { status: "instrumental", lines: [] };
        else if (data.syncedLyrics)
            result = { status: "synced", lines: parseLrc(data.syncedLyrics) };
        else if (data.plainLyrics)
            result = { status: "plain", lines: data.plainLyrics.split("\n").map(t => ({ t: -1, text: t.trim() })) };
        else
            result = { status: "none", lines: [] };
        if (result.status !== "error") {
            const c = Object.assign({}, cache);
            const keys = Object.keys(c);
            if (keys.length >= 60)
                delete c[keys[0]];
            c[k] = result;
            cache = c;
        }
        if (k === key)
            apply(result);
    }

    function apply(r: var): void {
        status = r.status;
        lines = r.lines;
        tick();
    }

    // "[01:23.45] text" -> { t: 83.45, text }; several stamps on one line
    // are all kept; sorted by time.
    function parseLrc(lrc: string): var {
        const out = [];
        for (const raw of lrc.split("\n")) {
            const re = /\[(\d+):(\d+(?:\.\d+)?)\]/g;
            const stamps = [];
            let m;
            while ((m = re.exec(raw)) !== null)
                stamps.push(parseInt(m[1]) * 60 + parseFloat(m[2]));
            if (stamps.length === 0)
                continue;
            const text = raw.replace(/\[[^\]]*\]/g, "").trim();
            for (const t of stamps)
                out.push({ t, text });
        }
        return out.sort((a, b) => a.t - b.t);
    }

    // ---- Position --------------------------------------------------------------------
    // Estimated between the player's reports: last report + time since, while playing.
    property real basePos: 0
    property real baseTime: 0
    Connections {
        target: root.player
        ignoreUnknownSignals: true
        function onPositionChanged() { root.resync(); }
        function onIsPlayingChanged() { root.resync(); }
    }
    function resync(): void {
        basePos = player?.position ?? 0;
        baseTime = Date.now();
    }
    // When line `i` is sung, in seconds: { start, end }. The end is the next
    // line's start (a little before it), but not much longer than the line
    // needs (instrumental gaps), estimated from its length.
    function span(i: int): var {
        const l = lines[i];
        if (!l)
            return { start: 0, end: 1 };
        const next = lines[i + 1];
        const need = Math.max(1.6, (l.text?.length ?? 10) * 0.16);
        const end = next ? Math.min(next.t - 0.12, l.t + need) : l.t + need;
        return { start: l.t, end: Math.max(l.t + 0.3, end) };
    }

    function position(): real {
        return basePos + (Media.playing ? (Date.now() - baseTime) / 1000 : 0);
    }

    // Ask the player for its position every 2 s.
    Timer {
        interval: 2000
        repeat: true
        running: root.wanted && Media.playing && root.hasLines
        onTriggered: root.player?.positionChanged()
    }
    // Find the current line, then sleep until the next one is due (synced
    // lyrics: lines change on time, not up to 250 ms late; few wake-ups).
    // Re-checked on every position update too. Only `index` changing redraws.
    readonly property bool ticking: root.wanted && Media.playing && root.hasLines
    onTickingChanged: if (ticking) tick(); else lineTimer.stop()
    onBasePosChanged: if (ticking) tick()
    Timer {
        id: lineTimer
        onTriggered: root.tick()
    }
    function tick(): void {
        if (status === "plain") {
            const i = length > 0 ? Math.min(lines.length - 1, Math.floor(position() / length * lines.length)) : -1;
            if (i !== index)
                index = i;
            lineTimer.interval = 1000;
            if (ticking)
                lineTimer.restart();
            return;
        }
        if (status !== "synced") {
            index = -1;
            return;
        }
        // Shown a little early, so the line is there when it is sung.
        const p = position() + 0.25;
        let i = -1;
        for (let j = 0; j < lines.length && lines[j].t <= p; j++)
            i = j;
        if (i !== index)
            index = i;
        // Wake up when the next line is due (at most 2 s, in case of a seek
        // the player didn't report).
        const next = lines[i + 1];
        lineTimer.interval = next ? Math.max(20, Math.min(2000, Math.round((next.t - p) * 1000) + 5)) : 2000;
        if (ticking)
            lineTimer.restart();
    }
}
