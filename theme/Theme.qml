pragma Singleton

import QtQuick
import Quickshell
import qs.core

// The single source of truth for how things look. Components bind to Theme only,
// never to Config directly, so validation and derived values live in one place.
Singleton {
    id: root

    // ---- Effect flags (low-power mode overrides everything) ----------------
    readonly property bool lowPower: Config.performance.lowPower
    readonly property bool animations: !lowPower && Config.effects.animations
    readonly property bool blur: !lowPower && Config.effects.blur
    readonly property bool liquidGlass: !lowPower && Config.effects.liquidGlass

    // ---- Colours ------------------------------------------------------------
    readonly property bool dark: Config.appearance.theme !== "light"

    // Falls back to the default accent if the config holds something invalid.
    readonly property color accent: validColor(Config.appearance.accent, "#7aa2f7")
    readonly property color onAccent: luminance(accent) > 0.55 ? "#111216" : "#ffffff"

    readonly property color base: dark ? "#14151a" : "#f3f4f7"     // panel colour, opaque
    readonly property color fg: dark ? "#e8e9ee" : "#16171c"
    readonly property color fgMuted: Qt.alpha(fg, 0.62)
    readonly property color fgDisabled: Qt.alpha(fg, 0.38)
    readonly property color border: Qt.alpha(fg, dark ? 0.08 : 0.10)
    readonly property color hover: Qt.alpha(fg, 0.06)
    readonly property color pressed: Qt.alpha(fg, 0.12)

    // Panel background: more transparent when blur is behind it; still slightly
    // translucent without blur so the "effects off" look stays light.
    readonly property color surface: Qt.alpha(base, blur ? 0.70 : 0.92)
    readonly property color surfaceRaised: Qt.alpha(fg, dark ? 0.05 : 0.04)

    // ---- Spacing / shape (4px grid) ------------------------------------------
    readonly property QtObject space: QtObject {
        readonly property int xs: 4
        readonly property int s: 8
        readonly property int m: 12
        readonly property int l: 16
        readonly property int xl: 24
    }

    readonly property QtObject radius: QtObject {
        readonly property int s: 8
        readonly property int m: 12
        readonly property int l: 18
        readonly property int full: 999
    }

    // ---- Typography -----------------------------------------------------------
    readonly property QtObject font: QtObject {
        readonly property string family: Config.appearance.fontFamily
        readonly property string icons: Config.appearance.iconFontFamily
        readonly property int small: 12
        readonly property int body: 14
        readonly property int title: 18
        readonly property int display: 32
    }

    // ---- Motion ---------------------------------------------------------------
    // Durations collapse to 0 when animations are off, so components can always
    // use a Behavior with Theme.anim.* and get instant changes in low-power mode.
    readonly property QtObject anim: QtObject {
        readonly property int fast: root.animations ? 120 : 0
        readonly property int normal: root.animations ? 200 : 0
        readonly property int slow: root.animations ? 320 : 0
        readonly property int easing: Easing.OutCubic
        readonly property int easingIn: Easing.InCubic
    }

    // ---- Bar ----------------------------------------------------------------------
    readonly property string barPosition: Config.appearance.barPosition === "bottom" ? "bottom" : "top"
    readonly property int barHeight: 36

    // ---- Helpers ------------------------------------------------------------------
    function validColor(value: string, fallback: string): color {
        return /^#([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$/.test(value) ? value : fallback;
    }

    // Relative luminance (sRGB approximation, good enough for picking text colour).
    function luminance(c: color): real {
        return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b;
    }
}
