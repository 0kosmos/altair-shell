// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Shapes
import qs.services
import qs.theme

// Music visualizer drawn from services/Cava.qml. Styles:
//   bars    rounded bars rising from the bottom
//   mirror  bars growing up and down from the centre line
//   wave    a smooth line through the levels, softly filled below
//   peaks   bars with a cap on top that falls back slowly
//   circle  bars radiating from a ring (mirrored left/right), leaving the
//           middle free (the Visualizer widget puts the album art there;
//           ringRadius/ringLength fit it around something else)
//   glow    a soft round glow that swells with the music (behind album art)
// It redraws only when cava delivers a frame (at the chosen fps), never at
// the monitor's refresh rate; with no data (paused, cava missing) the bars
// rest as small dots.
Item {
    id: root

    property string style: "bars"
    // Circle: inner radius and longest bar in px (-1 = from the size), and
    // whether the thin ring line is drawn.
    property real ringRadius: -1
    property real ringLength: -1
    property bool ringLine: true
    // Counts as a cava user only while shown and not covered.
    property bool active: true
    property bool counted: false
    onActiveChanged: sync()
    Component.onCompleted: sync()
    Component.onDestruction: if (counted) Cava.users--
    function sync(): void {
        if (active && !counted) { Cava.users++; counted = true; }
        else if (!active && counted) { Cava.users--; counted = false; }
    }

    readonly property int n: Cava.bars
    readonly property var v: Cava.values
    readonly property color barColor: Qt.alpha(Theme.accent, 0.85)
    function level(i: int): real {
        return Math.max(0, Math.min(1, v[i] ?? 0));
    }

    // Small shapes (ring, glow) are scaled to the music itself: `loudest` is the
    // recent loudest bar, falling slowly (~2 s to halve), so the loudest
    // moment always reaches full size whatever the song or volume.
    // (Not called `top`: that is Item's anchor line.) Bars,
    // wave and peaks show cava's values as they are (sensitivity setting).
    property real loudest: 0.2
    readonly property bool normalised: style === "circle" || style === "glow"
    function norm(i: int): real {
        return Math.min(1, level(i) / loudest);
    }
    // Overall loudness for the glow: the mean of the loudest third of bars.
    readonly property real energy: {
        if (style !== "glow" || n === 0 || v.length === 0)
            return 0;
        const s = [];
        for (let i = 0; i < n; i++)
            s.push(norm(i));
        s.sort((a, b) => b - a);
        const k = Math.max(1, Math.floor(n / 3));
        let sum = 0;
        for (let i = 0; i < k; i++)
            sum += s[i];
        return sum / k;
    }

    // Peaks: per bar the highest recent level, falling ~1.2 heights/s.
    property var peaks: []
    onVChanged: {
        if (normalised && v.length > 0) {
            let m = 0;
            for (let i = 0; i < n; i++)
                m = Math.max(m, level(i));
            loudest = Math.max(0.08, m, loudest * Math.pow(0.5, 1 / (2 * Cava.fps)));
        }
        if (style !== "peaks")
            return;
        if (v.length === 0) {
            peaks = [];
            return;
        }
        const fall = 1.2 / Cava.fps;
        const p = [];
        for (let i = 0; i < n; i++)
            p.push(Math.max(level(i), (peaks[i] ?? 0) - fall));
        peaks = p;
    }

    // ---- Bars / mirror -------------------------------------------------------------
    Row {
        anchors.fill: parent
        visible: root.style === "bars" || root.style === "mirror" || root.style === "peaks"
        spacing: 3
        readonly property real barW: (width - spacing * (root.n - 1)) / root.n

        Repeater {
            model: root.n
            Item {
                required property int index
                width: parent.barW
                height: parent.height
                readonly property real room: root.style === "peaks" ? height - 6 : height
                // One fixed colour for all bars: the scene graph then draws
                // them as one batch, and nothing but the height changes per
                // frame (a per-bar colour cost several % CPU at 30 fps here).
                Rectangle {
                    width: parent.width
                    height: Math.max(width, Math.min(1, root.v[index] ?? 0) * parent.room)
                    radius: Math.min(width / 2, 3)
                    y: root.style === "mirror" ? (parent.height - height) / 2 : parent.height - height
                    color: root.barColor
                }
                // Peak cap.
                Rectangle {
                    visible: root.style === "peaks" && (root.peaks[index] ?? 0) > 0.02
                    width: parent.width
                    height: 3
                    radius: 1.5
                    y: parent.height - 3 - (root.peaks[index] ?? 0) * (parent.height - 5) - 2
                    color: Theme.fg
                    opacity: 0.85
                }
            }
        }
    }

    // ---- Circle ----------------------------------------------------------------------
    Item {
        id: circle
        anchors.fill: parent
        visible: root.style === "circle"
        readonly property real size: Math.min(width, height)
        // Inner ring radius and the longest a bar can grow.
        readonly property real r0: root.ringRadius > 0 ? root.ringRadius : size * 0.3
        readonly property real len: root.ringLength > 0 ? root.ringLength : size * 0.19

        Rectangle {
            visible: root.ringLine
            anchors.centerIn: parent
            width: circle.r0 * 2 - 4
            height: width
            radius: width / 2
            color: "transparent"
            border.width: 1.5
            border.color: Qt.alpha(Theme.accent, 0.5)
        }

        // 2 × n bars: the right half bass at the top going clockwise to the
        // treble at the bottom, the left half its mirror image.
        Repeater {
            model: circle.visible ? root.n * 2 : 0
            Item {
                required property int index
                readonly property int bar: index < root.n ? index : root.n * 2 - 1 - index
                // Square root: quiet parts still move visibly on short bars.
                readonly property real lv: Math.sqrt(root.norm(bar))
                anchors.fill: parent
                rotation: (index + 0.5) * 360 / (root.n * 2)
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Math.max(2, circle.r0 * 2 * Math.PI / (root.n * 2) * 0.55)
                    height: Math.max(width, parent.lv * circle.len)
                    radius: width / 2
                    y: parent.height / 2 - circle.r0 - height
                    color: root.barColor
                }
            }
        }
    }

    // ---- Glow ----------------------------------------------------------------------
    // One radial gradient; only its scale and opacity follow the music, so a
    // frame is cheap to draw. Drawn at a fixed 200 px and scaled: gradient
    // coordinates bound to a size that starts at 0 were never redrawn
    // (nothing showed).
    Shape {
        id: glow
        anchors.centerIn: parent
        width: 200
        height: 200
        visible: root.style === "glow"
        preferredRendererType: Shape.GeometryRenderer
        // Pow > 1: calm parts stay soft, loud ones bloom.
        readonly property real e: Math.pow(root.energy, 1.6)
        scale: Math.min(root.width, root.height) / 200 * (0.8 + 0.35 * e)
        opacity: 0.25 + 0.75 * e
        ShapePath {
            strokeWidth: -1
            fillGradient: RadialGradient {
                centerX: 100
                centerY: 100
                centerRadius: 100
                focalX: 100
                focalY: 100
                // Strong up to where album art usually ends (~60 %), then a
                // soft falloff: the part that shows is the halo around it.
                GradientStop { position: 0; color: Qt.alpha(Theme.accent, 0.9) }
                GradientStop { position: 0.58; color: Qt.alpha(Theme.accent, 0.9) }
                GradientStop { position: 0.8; color: Qt.alpha(Theme.accent, 0.42) }
                GradientStop { position: 1; color: Qt.alpha(Theme.accent, 0) }
            }
            PathAngleArc {
                centerX: 100
                centerY: 100
                radiusX: 100
                radiusY: 100
                sweepAngle: 360
            }
        }
    }

    // ---- Wave ----------------------------------------------------------------------
    Shape {
        id: wave
        anchors.fill: parent
        visible: root.style === "wave"
        // Geometry renderer: the curve renderer re-processed the whole shape
        // every frame (~11 % CPU at 30 fps here).
        preferredRendererType: Shape.GeometryRenderer
        // That renderer has no antialiasing. A multisampled layer would fix
        // it but cost ~8 % CPU at 60 fps here; instead the curve has more
        // points and a faint, wider line underneath softens the steps.

        // A smooth curve through the levels (Catmull-Rom, 4 points per bar).
        readonly property var pts: {
            const w = width, h = height, n = root.n;
            if (n < 2 || w <= 0)
                return [Qt.point(0, h), Qt.point(w, h)];
            const y = i => h - 2 - root.level(Math.max(0, Math.min(n - 1, i))) * (h - 6);
            const l = [];
            for (let i = 0; i < n - 1; i++) {
                const p0 = y(i - 1), p1 = y(i), p2 = y(i + 1), p3 = y(i + 2);
                for (let k = 0; k < 4; k++) {
                    const t = k / 4, t2 = t * t, t3 = t2 * t;
                    const yy = 0.5 * (2 * p1 + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3);
                    l.push(Qt.point((i + t) * w / (n - 1), Math.max(1, Math.min(h - 1, yy))));
                }
            }
            l.push(Qt.point(w, y(n - 1)));
            return l;
        }

        // Soft fill under the line.
        ShapePath {
            strokeWidth: -1
            fillGradient: LinearGradient {
                y1: 0
                y2: wave.height
                GradientStop { position: 0; color: Qt.alpha(Theme.accent, 0.35) }
                GradientStop { position: 1; color: Qt.alpha(Theme.accent, 0) }
            }
            PathPolyline {
                path: [Qt.point(0, wave.height)].concat(wave.pts).concat([Qt.point(wave.width, wave.height)])
            }
        }
        // Soft edge under the line (cheap stand-in for antialiasing).
        ShapePath {
            strokeWidth: 4.5
            strokeColor: Qt.alpha(Theme.accent, 0.22)
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathPolyline {
                path: wave.pts
            }
        }
        // The line.
        ShapePath {
            strokeWidth: 1.8
            strokeColor: Theme.accent
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathPolyline {
                path: wave.pts
            }
        }
    }
}
