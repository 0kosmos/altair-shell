// SPDX-License-Identifier: GPL-3.0-or-later
pragma Singleton

import QtQuick
import Quickshell
import qs.core
import "palettes.js" as Palettes

// The single source of truth for how things look. Components bind to Theme only,
// never to Config directly, so validation and derived values live in one place.
Singleton {
    id: root

    // ---- Effect flags (low-power mode overrides everything) ----------------
    readonly property bool lowPower: Config.performance.lowPower
    readonly property bool animations: !lowPower && Config.effects.animations
    readonly property bool blur: !lowPower && Config.effects.blur
    readonly property bool liquidGlass: !lowPower && Config.effects.liquidGlass
    // Panel decoration: 0 none, 1 glow, 2 aurora, 3 grain (off in low-power).
    // Panel decorations (shaders/panelfx.frag modes, in this order).
    readonly property list<string> panelStyles: ["none", "glow", "aurora", "grain", "mesh", "sheen", "edge", "dusk", "lines", "dots",
        "flow", "nebula", "waves", "prism", "stars", "pulse"]
    readonly property int panelFx: lowPower ? 0 : Math.max(0, panelStyles.indexOf(Config.effects.panelStyle))
    // Modes 10+ move (only while a panel or menu is open, see GlassBackground).
    readonly property bool panelFxAnimated: panelFx >= 10 && animations && Config.effects.panelAnimate
    readonly property real panelIntensity: Math.max(0.3, Math.min(1.6, Config.effects.panelIntensity || 1))
    readonly property real panelSpeed: Math.max(0.25, Math.min(3, Config.effects.panelSpeed || 1))
    // Second and third colour of the decoration (alpha 0 = derived from the
    // accent in the shader).
    readonly property bool panelPaletteColors: Config.effects.panelColors === "palette" && usingPalette
    readonly property vector4d panelC2: panelPaletteColors ? vec(paletteColors[2]) : Qt.vector4d(0, 0, 0, 0)
    readonly property vector4d panelC3: panelPaletteColors ? vec(paletteColors[1]) : Qt.vector4d(0, 0, 0, 0)
    function vec(c: color): vector4d {
        return Qt.vector4d(c.r, c.g, c.b, 1);
    }
    // How panels open/close: "glide" | "spring" | "zoom" | "drop" | "fade".
    readonly property string panelMotion: ["spring", "zoom", "drop", "fade"].indexOf(Config.effects.panelMotion) !== -1 ? Config.effects.panelMotion : "glide"

    // ---- Colours ------------------------------------------------------------
    // Palette: "default" (the built-in dark/light colours), the id of a
    // built-in palette (theme/palettes.js), or "custom". A palette has five
    // colours: background, surface, muted, text, accent.
    readonly property var paletteColors: {
        const id = Config.appearance.palette;
        if (id === "auto") {
            const c = Config.appearance.autoColors;
            return c && c.length === 5 && Array.from(c).every(v => /^#[0-9a-fA-F]{6}$/.test(v)) ? Array.from(c) : null;
        }
        if (id === "custom") {
            const c = Config.appearance.customPalette;
            return c && c.length === 5 && c.every(v => /^#[0-9a-fA-F]{6}$/.test(v)) ? c : null;
        }
        const p = Palettes.find(id);
        return p ? p.colors : null;
    }
    readonly property bool usingPalette: paletteColors !== null
    readonly property var palettes: Palettes.list
    readonly property var paletteRoles: Palettes.roles

    // Dark or light: chosen by the user, or by the palette's background.
    readonly property bool dark: usingPalette ? luminance(paletteColors[0]) < 0.2 : Config.appearance.theme !== "light"

    // Accent setting: a colour (#RRGGBB); "mono" = monochrome, which adapts to
    // the theme (near-white on dark, dark grey on light); or "palette" = the
    // palette's accent. Custom colours are used exactly as chosen, even if that
    // means white on the light theme.
    readonly property bool monoAccent: Config.appearance.accent === "mono"
    readonly property color monoColor: usingPalette ? paletteColors[3] : dark ? "#e8e9ee" : "#2b2d33"
    readonly property color chosenAccent: monoAccent ? monoColor
        : Config.appearance.accent === "palette" ? (usingPalette ? paletteColors[4] : "#7aa2f7")
        : validColor(Config.appearance.accent, "#7aa2f7")
    readonly property color accent: chosenAccent
    // Text/icons drawn on top of the accent: whichever of dark/white reads better.
    readonly property color onAccent: contrast(accent, "#111216") > contrast(accent, "#ffffff") ? "#111216" : "#ffffff"

    readonly property color base: usingPalette ? paletteColors[0] : dark ? "#14151a" : "#f3f4f7"  // panel colour, opaque
    readonly property color fg: usingPalette ? paletteColors[3] : dark ? "#e8e9ee" : "#16171c"
    readonly property color fgMuted: Qt.alpha(fg, 0.62)
    readonly property color fgDisabled: Qt.alpha(fg, 0.38)
    readonly property color border: usingPalette ? Qt.alpha(paletteColors[2], 0.55) : Qt.alpha(fg, dark ? 0.08 : 0.10)
    readonly property color hover: Qt.alpha(fg, 0.06)
    readonly property color pressed: Qt.alpha(fg, 0.12)
    readonly property color critical: dark ? "#f7768e" : "#d1364f"

    // Panel background: more transparent when blur is behind it; still slightly
    // translucent without blur so the "effects off" look stays light.
    readonly property color surface: Qt.alpha(base, blur ? 0.70 : 0.92)

    // Liquid glass tints (straight rgba, for the shader): a lighter, more
    // transparent top fading into the base colour.
    readonly property vector4d glassTop: usingPalette ? glassFrom(paletteColors[1], dark ? 0.40 : 0.50)
        : dark ? Qt.vector4d(0.22, 0.23, 0.27, blur ? 0.40 : 0.85)
               : Qt.vector4d(1.0, 1.0, 1.0, blur ? 0.50 : 0.90)
    readonly property vector4d glassBottom: Qt.vector4d(base.r, base.g, base.b, blur ? 0.58 : 0.92)
    readonly property real glassRim: dark ? 1.0 : 0.6
    // Rim light: the palette's light colour on dark themes, white on light
    // ones (where the text colour is dark).
    readonly property vector4d glassRimColor: {
        const c = dark && usingPalette ? Qt.lighter(paletteColors[3], 1.05) : Qt.color("#ffffff");
        return Qt.vector4d(c.r, c.g, c.b, 1);
    }
    readonly property color surfaceRaised: usingPalette ? Qt.alpha(paletteColors[1], 0.75) : Qt.alpha(fg, dark ? 0.05 : 0.04)

    // A palette colour, made a bit lighter, as a straight rgba glass tint.
    function glassFrom(c: color, alpha: real): vector4d {
        const l = Qt.lighter(c, dark ? 1.35 : 1.04);
        return Qt.vector4d(l.r, l.g, l.b, blur ? alpha : 0.88);
    }

    // ---- Spacing / shape (4px grid) ------------------------------------------
    readonly property QtObject space: QtObject {
        readonly property int xs: 4
        readonly property int s: 8
        readonly property int m: 12
        readonly property int l: 16
        readonly property int xl: 24
    }

    // Corner roundness (Settings > Appearance > Corners): 0 = square,
    // 1 = Altair's default, 2 = very round. Scales every container corner
    // (panels, menus, cards, bar, dock, widgets, Settings); circles and
    // pills stay round.
    readonly property real corners: Config.ready ? Math.max(0, Math.min(2, Config.appearance.corners)) : 1
    readonly property QtObject radius: QtObject {
        readonly property int s: Math.round(8 * root.corners)
        readonly property int m: Math.round(12 * root.corners)
        readonly property int l: Math.round(18 * root.corners)
        readonly property int full: 999
    }

    // ---- Typography -----------------------------------------------------------
    // Launcher search animations: "off" | "subtle" | "lively".
    readonly property string searchAnim: lowPower ? "off" : (["off", "lively"].indexOf(Config.effects.searchAnimations) !== -1 ? Config.effects.searchAnimations : "subtle")
    // Desktop widgets' font ("" = the UI font).
    readonly property string widgetFont: Config.appearance.widgetFont || ""
    readonly property QtObject font: QtObject {
        readonly property string family: Config.appearance.fontFamily
        readonly property string icons: Config.appearance.iconFontFamily
        readonly property int icon: 18
        readonly property int small: 12
        readonly property int body: 14
        readonly property int title: 18
        readonly property int display: 32
    }

    // ---- Motion ---------------------------------------------------------------
    // Durations collapse to 0 when animations are off, so components can always
    // use a Behavior with Theme.anim.* and get instant changes in low-power mode.
    readonly property QtObject anim: QtObject {
        readonly property int fast: root.animations ? 160 : 0     // hover, press, colour
        readonly property int normal: root.animations ? 260 : 0   // move, open
        readonly property int slow: root.animations ? 380 : 0     // large movements
        readonly property int easing: Easing.OutCubic
        readonly property int easingIn: Easing.InCubic
        // Smooth deceleration with no overshoot; for things that slide.
        readonly property int easingSlide: Easing.OutQuint
        // Buttons shrink to this while pressed, then spring back.
        readonly property real pressScale: root.animations ? 0.94 : 1
    }

    // How much the screen dims while something is dragged (Snap / DragOverlay).
    readonly property real dragDim: Math.max(0, Math.min(0.6, Config.windows.dragDim))

    // ---- Bar ----------------------------------------------------------------------
    // "top" | "bottom" | "left" | "right". Popups that open "below the bar"
    // treat a side bar like a top bar (barAtTop).
    readonly property string barPosition: ["bottom", "left", "right"].indexOf(Config.appearance.barPosition) !== -1 ? Config.appearance.barPosition : "top"
    readonly property bool barVertical: barPosition === "left" || barPosition === "right"
    readonly property bool barAtTop: barPosition !== "bottom"
    readonly property int barHeight: 36
    // The bar's size across its edge (height when horizontal, width when vertical).
    readonly property int barThickness: barHeight
    // Gap between the floating bar and the screen edges.
    readonly property int barGap: 8

    // ---- Helpers ------------------------------------------------------------------
    function validColor(value: string, fallback: string): color {
        return /^#([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$/.test(value) ? value : fallback;
    }

    // WCAG relative luminance (linearised sRGB), 0 = black, 1 = white.
    function luminance(c: color): real {
        const lin = v => v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4);
        return 0.2126 * lin(c.r) + 0.7152 * lin(c.g) + 0.0722 * lin(c.b);
    }

    // WCAG contrast ratio, 1 (identical) … 21 (black on white).
    function contrast(a: color, b: color): real {
        const la = luminance(a);
        const lb = luminance(b);
        return (Math.max(la, lb) + 0.05) / (Math.min(la, lb) + 0.05);
    }
}
