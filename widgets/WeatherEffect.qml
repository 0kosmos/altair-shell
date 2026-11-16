// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import qs.theme

// Weather drawn behind the Weather widget's text (Settings > Widgets >
// Weather effects), from the WMO weather code:
//   rain / drizzle / showers   falling streaks
//   snow                       drifting flakes
//   thunderstorm               rain + a rare soft flash
//   fog                        haze           (static)
//   clear                      sun glow by day, a few stars at night (static)
//
// Static looks are painted once on a Canvas. Moving ones are a GPU shader
// (shaders/weather.frag) whose `time` a Timer advances ~24 times a second, so
// the CPU never paints drops itself (a Canvas version cost ~9 % of a core
// here). They only run while `running` (widget not covered, animations on).
Item {
    id: root

    property int code: 0
    property bool day: true
    property bool running: true
    property color tint: Theme.fg
    // Corner radius of the widget (drawing is clipped to it).
    property real radius: Theme.radius.l
    // Which parts to draw: the static looks (inside the widget) and/or the
    // moving ones (WeatherWidget puts those in a small window of their own).
    property bool drawStatic: true
    property bool drawMoving: true

    readonly property string kind: {
        const c = code;
        if (c >= 95) return "storm";
        if ((c >= 71 && c <= 77) || c === 85 || c === 86) return "snow";
        if ((c >= 51 && c <= 67) || (c >= 80 && c <= 82)) return "rain";
        if (c === 45 || c === 48) return "fog";
        if (c <= 1) return "clear";
        return "";
    }
    readonly property bool moving: kind === "rain" || kind === "storm" || kind === "snow"
    // Drizzle / light snow: fewer drops; heavy: more.
    readonly property real amount: kind === "snow" ? (code === 71 || code === 85 ? 0.45 : code === 75 || code === 86 ? 1 : 0.7)
        : code >= 51 && code <= 57 ? 0.35 : code === 65 || code === 82 || kind === "storm" ? 1 : 0.65

    // ---- Static: clear sky, fog (painted once) ------------------------------------
    Canvas {
        id: still
        anchors.fill: parent
        visible: root.drawStatic && (root.kind === "clear" || root.kind === "fog")
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            ctx.beginPath();
            ctx.roundedRect(0, 0, width, height, root.radius, root.radius);
            ctx.clip();
            const c = root.tint;
            if (root.kind === "clear" && root.day) {
                const r = height * 1.1, cx = width - height * 0.25, cy = -height * 0.2;
                const g = ctx.createRadialGradient(cx, cy, 0, cx, cy, r);
                g.addColorStop(0, Qt.rgba(1, 0.86, 0.5, 0.26));
                g.addColorStop(0.45, Qt.rgba(1, 0.8, 0.45, 0.08));
                g.addColorStop(1, Qt.rgba(1, 0.8, 0.45, 0));
                ctx.fillStyle = g;
                ctx.fillRect(0, 0, width, height);
            } else if (root.kind === "clear") {
                for (let i = 0; i < 10; i++) {
                    // Fixed pseudo-random spots (the same every paint).
                    const fx = Math.abs(Math.sin(i * 12.9898) * 43758.5453) % 1;
                    const fy = Math.abs(Math.sin(i * 78.233) * 12543.123) % 1;
                    ctx.fillStyle = Qt.rgba(c.r, c.g, c.b, 0.3 + (i % 4) * 0.1);
                    ctx.beginPath();
                    ctx.arc(fx * width, fy * height * 0.75, i % 3 === 0 ? 1.3 : 0.8, 0, 6.2832);
                    ctx.fill();
                }
            } else if (root.kind === "fog") {
                const g = ctx.createLinearGradient(0, 0, 0, height);
                g.addColorStop(0, Qt.rgba(c.r, c.g, c.b, 0));
                g.addColorStop(0.55, Qt.rgba(c.r, c.g, c.b, 0.07));
                g.addColorStop(1, Qt.rgba(c.r, c.g, c.b, 0.15));
                ctx.fillStyle = g;
                ctx.fillRect(0, 0, width, height);
            }
        }
    }
    onKindChanged: still.requestPaint()
    onDayChanged: still.requestPaint()
    onTintChanged: still.requestPaint()
    onWidthChanged: still.requestPaint()
    onHeightChanged: still.requestPaint()

    // ---- Moving: rain, snow, storm (GPU) ----------------------------------------------
    Loader {
        anchors.fill: parent
        active: root.drawMoving && root.moving
        sourceComponent: ShaderEffect {
            id: fx
            readonly property size size: Qt.size(width, height)
            readonly property real radius: root.radius
            property real time: Math.random() * 100
            readonly property real mode: root.kind === "snow" ? 2 : 1
            readonly property real amount: root.amount
            property real flash: 0
            readonly property vector4d tint: Qt.vector4d(root.tint.r, root.tint.g, root.tint.b, 1)
            fragmentShader: Qt.resolvedUrl("../shaders/weather.frag.qsb")

            property real nextFlash: 4
            Timer {
                // ~24 fps for rain; slow snow looks the same at 15 fps. Cost here:
                // ~4 % of a core for rain while visible (NVIDIA: ~1.5 ms per frame).
                interval: root.kind === "snow" ? 66 : 42
                repeat: true
                running: root.running && Theme.animations
                property real last: 0
                onRunningChanged: last = 0
                onTriggered: {
                    const now = Date.now();
                    const dt = last > 0 ? Math.min(0.1, (now - last) / 1000) : interval / 1000;
                    last = now;
                    fx.time += dt;
                    // Thunder: a soft flash every 6–14 s, fading quickly.
                    if (root.kind === "storm") {
                        fx.nextFlash -= dt;
                        if (fx.nextFlash <= 0) {
                            fx.flash = 1;
                            fx.nextFlash = 6 + Math.random() * 8;
                        } else if (fx.flash > 0) {
                            fx.flash = Math.max(0, fx.flash - dt * 3);
                        }
                    }
                }
            }
        }
    }
}
