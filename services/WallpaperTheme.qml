// SPDX-License-Identifier: GPL-3.0-or-later
pragma Singleton

import QtQuick
import Quickshell
import qs.core

// Colour themes that go with wallpapers (the theme row in the wallpaper
// picker). A "theme" is the appearance's palette + accent (+ the generated
// colours when the palette is "auto").
//
// Modes (Config.wallpaper.themeMode):
//   "keep"   changing the wallpaper never changes the theme
//   "saved"  a wallpaper with a saved theme gets it back; others get the
//            theme saved "for all wallpapers" (if any), else keep
//   "auto"   saved themes first; otherwise a palette is generated from the
//            wallpaper's colours
//
// Generating: wallpaper/PaletteExtractor.qml (a tiny Canvas in the wallpaper
// window) shrinks the picture to 48x27 and reads its pixels; colours() below
// turns them into the five palette roles. No external tools.
Singleton {
    id: root

    readonly property string mode: Config.ready && ["saved", "auto"].indexOf(Config.wallpaper.themeMode) !== -1 ? Config.wallpaper.themeMode : "keep"
    readonly property var saved: Config.ready && Config.wallpaper.themes && typeof Config.wallpaper.themes === "object" ? Config.wallpaper.themes : ({})

    // Set by PaletteExtractor when it exists: extract(path, callback(colors)).
    property var extractor: null

    // The current theme, as stored.
    function currentTheme(): var {
        const a = Config.appearance;
        const t = { palette: a.palette, accent: a.accent };
        if (a.palette === "auto")
            t.colors = Array.from(a.autoColors ?? []);
        return t;
    }

    function apply(t: var): void {
        if (!t)
            return;
        if (t.palette === "auto" && t.colors && t.colors.length === 5)
            Config.appearance.autoColors = t.colors;
        Config.appearance.palette = t.palette;
        Config.appearance.accent = t.accent;
    }

    function hasSaved(path: string): bool {
        return !!saved[path];
    }
    function saveFor(path: string): void {
        if (!path)
            return;
        const next = Object.assign({}, saved);
        next[path] = currentTheme();
        Config.wallpaper.themes = next;
    }
    function forget(path: string): void {
        const next = Object.assign({}, saved);
        delete next[path];
        Config.wallpaper.themes = next;
    }
    // "For all wallpapers": the theme for any wallpaper without its own.
    function saveForAll(): void {
        const next = Object.assign({}, saved);
        next["*"] = currentTheme();
        Config.wallpaper.themes = next;
    }

    // Pick a palette (from the picker's row). "auto" = generate from `path`.
    function choose(id: string, path: string): void {
        if (id === "auto")
            generate(path);
        else
            apply({ palette: id, accent: "palette" });
    }

    property bool generating: false
    function generate(path: string): void {
        if (!extractor || !path)
            return;
        generating = true;
        extractor.extract(Wallpapers.stillFor(path), colors => {
            generating = false;
            if (colors)
                apply({ palette: "auto", accent: "palette", colors });
        });
    }

    // ---- Wallpaper changed ------------------------------------------------------------
    property string last: ""
    Connections {
        target: Wallpapers
        function onCurrentChanged() {
            const p = Wallpapers.current;
            if (!Config.ready || !p || p === root.last)
                return;
            const first = root.last === "";
            root.last = p;
            if (first || root.mode === "keep")
                return;   // (startup: the theme is already the saved one)
            if (root.saved[p])
                root.apply(root.saved[p]);
            else if (root.mode === "auto")
                root.generate(p);
            else if (root.saved["*"])
                root.apply(root.saved["*"]);
        }
    }
    Component.onCompleted: last = Wallpapers.current

    // ---- Pixels -> palette -------------------------------------------------------------
    // `px`: RGBA bytes. Weighs colourful, mid-bright pixels for the hue; the
    // overall brightness decides dark or light. Returns 5 "#rrggbb".
    function colors(px: var): var {
        const bins = new Array(36).fill(0), sumS = new Array(36).fill(0);
        let lum = 0, n = 0;
        for (let i = 0; i < px.length; i += 4) {
            const r = px[i] / 255, g = px[i + 1] / 255, b = px[i + 2] / 255;
            const mx = Math.max(r, g, b), mn = Math.min(r, g, b), l = (mx + mn) / 2;
            lum += 0.2126 * r + 0.7152 * g + 0.0722 * b;
            n++;
            const d = mx - mn;
            if (d < 0.04)
                continue;   // grey: no hue
            const s = d / (1 - Math.abs(2 * l - 1) + 1e-6);
            let h = mx === r ? ((g - b) / d) % 6 : mx === g ? (b - r) / d + 2 : (r - g) / d + 4;
            h = (h * 60 + 360) % 360;
            const w = s * (1 - Math.abs(l - 0.5) * 1.6);   // colourful and not too dark/bright
            const k = Math.floor(h / 10);
            bins[k] += Math.max(0, w);
            sumS[k] += s * Math.max(0, w);
        }
        lum /= Math.max(1, n);
        // Strongest hue (with its neighbours, so a hue on a bin edge counts).
        let best = 0, bestW = -1;
        for (let k = 0; k < 36; k++) {
            const w = bins[k] + 0.5 * (bins[(k + 35) % 36] + bins[(k + 1) % 36]);
            if (w > bestW) { bestW = w; best = k; }
        }
        const colourful = bestW > n * 0.02;
        const hue = (best * 10 + 5) / 360;
        const sat = colourful ? Math.min(0.85, Math.max(0.45, sumS[best] / Math.max(1e-6, bins[best]))) : 0.08;
        const dark = lum < 0.62;
        const hex = (h, s, l) => {
            const c = Qt.hsla(h, s, l, 1);
            const t = v => Math.round(v * 255).toString(16).padStart(2, "0");
            return "#" + t(c.r) + t(c.g) + t(c.b);
        };
        const tint = Math.min(sat, 0.35);
        return dark
            ? [hex(hue, tint, 0.07), hex(hue, tint, 0.12), hex(hue, tint, 0.28), hex(hue, 0.15, 0.9), hex(hue, sat, 0.66)]
            : [hex(hue, tint, 0.95), hex(hue, tint, 0.89), hex(hue, tint, 0.74), hex(hue, 0.2, 0.12), hex(hue, sat, 0.42)];
    }
}
