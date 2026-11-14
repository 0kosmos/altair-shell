// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick
import QtQuick.Shapes
import qs.services
import qs.theme

// Music visualizer drawn from services/Cava.qml. Styles:
//   bars    rounded bars rising from the bottom
//   mirror  bars growing up and down from the centre line
//   wave    a smooth line through the levels, softly filled below
// It redraws only when cava delivers a frame (at the chosen fps), never at
// the monitor's refresh rate; with no data (paused, cava missing) the bars
// rest as small dots.
Item {
    id: root

    property string style: "bars"
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
    function level(i: int): real {
        return Math.max(0, Math.min(1, v[i] ?? 0));
    }

    // ---- Bars / mirror -------------------------------------------------------------
    Row {
        anchors.fill: parent
        visible: root.style !== "wave"
        spacing: 3
        readonly property real barW: (width - spacing * (root.n - 1)) / root.n

        Repeater {
            model: root.n
            Item {
                required property int index
                width: parent.barW
                height: parent.height
                Rectangle {
                    readonly property real h: Math.max(width, root.level(index) * parent.height)
                    width: parent.width
                    height: h
                    radius: Math.min(width / 2, 3)
                    y: root.style === "mirror" ? (parent.height - h) / 2 : parent.height - h
                    // Brighter as the bar rises.
                    color: Qt.alpha(Theme.accent, 0.45 + 0.55 * root.level(index))
                }
            }
        }
    }

    // ---- Wave ----------------------------------------------------------------------
    Shape {
        id: wave
        anchors.fill: parent
        visible: root.style === "wave"
        preferredRendererType: Shape.CurveRenderer

        // A smooth curve through the levels (Catmull-Rom, 3 points per bar).
        readonly property var pts: {
            const w = width, h = height, n = root.n;
            if (n < 2 || w <= 0)
                return [Qt.point(0, h), Qt.point(w, h)];
            const y = i => h - 2 - root.level(Math.max(0, Math.min(n - 1, i))) * (h - 6);
            const l = [];
            for (let i = 0; i < n - 1; i++) {
                const p0 = y(i - 1), p1 = y(i), p2 = y(i + 1), p3 = y(i + 2);
                for (let k = 0; k < 3; k++) {
                    const t = k / 3, t2 = t * t, t3 = t2 * t;
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
        // The line.
        ShapePath {
            strokeWidth: 2
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
