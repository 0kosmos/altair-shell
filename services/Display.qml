// SPDX-License-Identifier: GPL-3.0-or-later
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.core

// Screen brightness and colour.
//
// Hardware (the screen's own settings, no quality loss):
//   - laptops: the backlight (/sys/class/backlight), set through logind
//     (no root, no extra tool)
//   - external monitors: DDC/CI with `ddcutil` (brightness, contrast, colour
//     preset, red/green/blue gain). Needs access to /dev/i2c-* (the i2c-dev
//     module; most distributions give the logged-in user access, else the
//     `i2c` group). A DDC write takes ~0.3 s, so writes are queued and a
//     slider drag only sends its latest value.
// Software (Hyprland screen shader, for what the hardware can't do):
//   saturation, warmth (night light), gamma and dimming. One small shader,
//   written to $XDG_RUNTIME_DIR/altair/ and set with `hyprctl eval`; off
//   entirely (no shader) when everything is neutral. While on, Hyprland
//   draws every frame through it and fullscreen apps lose direct scanout.
//   Screenshots are taken before it, so they don't show it.
Singleton {
    id: root

    readonly property string runDir: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/altair"

    // ---- Hardware ----------------------------------------------------------------
    // DDC monitors: [{ bus, connector, model, values: { "10": { cur, max }, ... },
    //                  presets: ["01", "05", ...] }]
    property var monitors: []
    readonly property bool hasDdc: monitors.length > 0
    // Laptop backlight: { name, cur, max } or null.
    property var backlight: null
    readonly property bool hasHardware: hasDdc || backlight !== null
    property bool detecting: true

    // Shown brightness, 0–100: the backlight, else the first monitor, else
    // the software dimming.
    readonly property int brightness: {
        if (backlight)
            return Math.round(backlight.cur * 100 / Math.max(1, backlight.max));
        if (hasDdc) {
            const v = monitors[0].values["10"];
            if (v)
                return Math.round(v.cur * 100 / Math.max(1, v.max));
        }
        return Math.round(dim * 100);
    }
    readonly property string icon: brightness < 34 ? "brightness_5" : brightness < 67 ? "brightness_6" : "brightness_7"

    // Every screen at once (bar button, keys).
    function setBrightness(pct: int): void {
        pct = Math.max(0, Math.min(100, Math.round(pct)));
        if (backlight)
            setBacklight(pct);
        for (let i = 0; i < monitors.length; i++)
            if (monitors[i].values["10"])
                setVcp(i, "10", Math.round(pct * monitors[i].values["10"].max / 100));
        if (!hasHardware)
            Config.display.dim = Math.max(0.2, pct / 100);
    }
    // A step that changes nothing (already at 0 or 100) still tells the
    // volume/brightness pop-up, so a key press always gets feedback.
    signal nudged()
    function changeBrightness(delta: int): void {
        const target = Math.max(0, Math.min(100, brightness + delta));
        if (target === brightness)
            nudged();
        else
            setBrightness(target);
    }

    // Value of a VCP feature of monitor `i` (0–max), or -1.
    function vcp(i: int, code: string): int {
        return monitors[i]?.values[code]?.cur ?? -1;
    }
    function vcpMax(i: int, code: string): int {
        return monitors[i]?.values[code]?.max ?? 100;
    }

    // Shown at once; the write follows through the queue.
    function setVcp(i: int, code: string, value: int): void {
        const m = monitors[i];
        if (!m)
            return;
        const list = monitors.slice();
        const values = Object.assign({}, m.values);
        values[code] = { cur: value, max: m.values[code]?.max ?? 100 };
        list[i] = Object.assign({}, m, { values });
        monitors = list;
        pendingSets[m.bus + ":" + code] = value;
        pump();
    }

    // MCCS colour preset names (VCP 14).
    readonly property var presetNames: ({ "01": "sRGB", "02": "Native", "03": "4000 K", "04": "5000 K", "05": "6500 K",
        "06": "7500 K", "07": "8200 K", "08": "9300 K", "09": "10000 K", "0a": "11500 K", "0b": "User 1", "0c": "User 2", "0d": "User 3" })

    // ---- Detection (once, at startup) ---------------------------------------------
    Component.onCompleted: {
        Quickshell.execDetached(["mkdir", "-p", runDir]);
        backlightProc.running = true;
        detectProc.running = true;
    }
    // ddcutil missing or hanging: stop saying "looking" after a while.
    Timer {
        running: root.detecting
        interval: 10000
        onTriggered: root.detecting = false
    }
    Process {
        id: backlightProc
        command: ["sh", "-c", 'for d in /sys/class/backlight/*; do [ -r "$d/max_brightness" ] && echo "${d##*/} $(cat "$d/brightness") $(cat "$d/max_brightness")"; done']
        stdout: StdioCollector {
            onStreamFinished: {
                const first = text.trim().split("\n")[0] ?? "";
                const p = first.split(" ");
                if (p.length === 3 && Number(p[2]) > 0)
                    root.backlight = { name: p[0], cur: Number(p[1]), max: Number(p[2]) };
            }
        }
    }
    Process {
        id: detectProc
        command: ["ddcutil", "detect", "--terse"]
        stdout: StdioCollector {
            onStreamFinished: {
                const found = [];
                let cur = null;
                for (const raw of text.split("\n")) {
                    const line = raw.trim();
                    if (line.startsWith("Display ")) {
                        cur = { bus: -1, connector: "", model: "", values: {}, presets: [] };
                        found.push(cur);
                    } else if (cur && line.startsWith("I2C bus:")) {
                        cur.bus = Number(line.replace(/.*i2c-/, ""));
                    } else if (cur && line.startsWith("DRM connector:")) {
                        cur.connector = line.replace(/.*card\d+-/, "");
                    } else if (cur && line.startsWith("Monitor:")) {
                        cur.model = line.split(":")[2] ?? "";
                    }
                }
                root.monitors = found.filter(m => m.bus >= 0);
                for (let i = 0; i < root.monitors.length; i++) {
                    root.queue.push({ kind: "read", i, args: ["getvcp", "10", "12", "14", "16", "18", "1A", "--brief"] });
                    root.queue.push({ kind: "caps", i, args: ["capabilities"] });
                }
                root.pump();
            }
        }
    }

    // ---- DDC queue: one ddcutil at a time ---------------------------------------------
    property var queue: []
    property var pendingSets: ({})
    function pump(): void {
        if (ddc.running)
            return;
        let job = queue.shift();
        if (!job) {
            const key = Object.keys(pendingSets)[0];
            if (key === undefined) {
                detecting = false;
                return;
            }
            const v = pendingSets[key];
            delete pendingSets[key];
            const [bus, code] = key.split(":");
            job = { kind: "set", bus: Number(bus), args: ["setvcp", code, String(v), "--noverify"] };
        }
        ddc.job = job;
        const bus = job.bus ?? monitors[job.i]?.bus;
        ddc.command = ["ddcutil", "--bus", String(bus)].concat(job.args);
        ddc.running = true;
    }
    Process {
        id: ddc
        property var job: null
        stdout: StdioCollector {
            onStreamFinished: {
                const job = ddc.job;
                if (!job || !root.monitors[job.i])
                    return;
                const list = root.monitors.slice();
                const m = Object.assign({}, list[job.i]);
                if (job.kind === "read") {
                    const values = {};
                    // "VCP 10 C 100 100" (continuous) / "VCP 14 SNC x08" or
                    // "VCP 14 CNC x00 x0b x00 x08" (non-continuous: last = value)
                    for (const line of text.split("\n")) {
                        const p = line.trim().split(/\s+/);
                        if (p[0] !== "VCP" || p.length < 4)
                            continue;
                        if (p[2] === "C")
                            values[p[1].toUpperCase()] = { cur: Number(p[3]), max: Number(p[4]) };
                        else if (p[2].endsWith("NC"))
                            values[p[1].toUpperCase()] = { cur: parseInt(p[p.length - 1].replace("x", ""), 16), max: 255 };
                    }
                    m.values = values;
                } else if (job.kind === "caps") {
                    // The colour presets the monitor lists: "14(01 04 05 ...)".
                    const r = /\b14\(([0-9A-Fa-f ]+)\)/.exec(text);
                    m.presets = r ? r[1].trim().split(/\s+/).map(s => s.toLowerCase()) : [];
                } else {
                    return;
                }
                list[job.i] = m;
                root.monitors = list;
            }
        }
        onExited: Qt.callLater(root.pump)
    }

    // ---- Backlight (laptops) --------------------------------------------------------
    property int backlightTarget: -1
    function setBacklight(pct: int): void {
        const raw = Math.max(1, Math.round(pct * backlight.max / 100));   // never fully black
        backlight = Object.assign({}, backlight, { cur: raw });
        backlightTarget = raw;
        backlightTimer.restart();
    }
    Timer {
        id: backlightTimer
        interval: 40
        onTriggered: Quickshell.execDetached(["busctl", "call", "org.freedesktop.login1", "/org/freedesktop/login1/session/auto",
            "org.freedesktop.login1.Session", "SetBrightness", "ssu", "backlight", root.backlight.name, String(root.backlightTarget)])
    }

    // ---- Software colour (screen shader) ----------------------------------------------
    readonly property real saturation: Config.ready ? Config.display.saturation : 1
    readonly property real warmth: Config.ready ? Config.display.warmth : 0
    readonly property real gamma: Config.ready ? Config.display.gamma : 1
    readonly property real dim: Config.ready ? Config.display.dim : 1
    readonly property bool shaderOn: Math.abs(saturation - 1) > 0.005 || warmth > 0.005
        || Math.abs(gamma - 1) > 0.005 || dim < 0.995

    function resetColour(): void {
        Config.display.saturation = 1;
        Config.display.warmth = 0;
        Config.display.gamma = 1;
        Config.display.dim = 1;
    }

    // White point of a colour temperature (K), relative to 6500 K
    // (Tanner Helland's approximation of the black-body curve).
    function kelvinRgb(k: real): var {
        const t = k / 100;
        const r = t <= 66 ? 255 : 329.698727446 * Math.pow(t - 60, -0.1332047592);
        const g = t <= 66 ? 99.4708025861 * Math.log(t) - 161.1195681661 : 288.1221695283 * Math.pow(t - 60, -0.0755148492);
        const b = t >= 66 ? 255 : t <= 19 ? 0 : 138.5177312231 * Math.log(t - 10) - 305.0447927307;
        const c = v => Math.max(0, Math.min(255, v)) / 255;
        return [c(r), c(g), c(b)];
    }

    // The user's own screen_shader (if any), put back when ours is off.
    property string originalShader: ""
    property bool originalRead: false
    Process {
        id: readOriginal
        running: true
        command: ["hyprctl", "getoption", "decoration:screen_shader", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const s = JSON.parse(text).str ?? "";
                    // A path of ours is left over from an earlier session.
                    root.originalShader = s.startsWith(root.runDir) || s === "[[EMPTY]]" ? "" : s;
                } catch (e) {}
                root.originalRead = true;
                root.scheduleApply();
            }
        }
    }

    onShaderOnChanged: scheduleApply()
    onSaturationChanged: scheduleApply()
    onWarmthChanged: scheduleApply()
    onGammaChanged: scheduleApply()
    onDimChanged: scheduleApply()
    function scheduleApply(): void {
        applyTimer.restart();
    }
    // Slider drags: at most one shader every 60 ms.
    Timer {
        id: applyTimer
        interval: 60
        onTriggered: root.apply()
    }

    property bool flip: false     // alternate file names so Hyprland reloads it
    property bool applied: false  // our shader is set
    function apply(): void {
        if (!Config.ready || !originalRead)
            return;
        if (!shaderOn) {
            if (applied)
                Hypr.hyprEval(`hl.config({ decoration = { screen_shader = ${JSON.stringify(originalShader)} } })`);
            applied = false;
            return;
        }
        const w = kelvinRgb(6500 - warmth * 3200);
        const f = n => n.toFixed(4);
        const src = `#version 300 es
// Generated by Altair (services/Display.qml). Saturation, warmth, gamma, dim.
precision highp float;
in vec2 v_texcoord;
uniform sampler2D tex;
out vec4 fragColor;
void main() {
    vec4 px = texture(tex, v_texcoord);
    vec3 c = pow(max(px.rgb, vec3(0.0)), vec3(${f(1 / gamma)}));
    float l = dot(c, vec3(0.2126, 0.7152, 0.0722));
    c = mix(vec3(l), c, ${f(saturation)});
    c *= vec3(${f(w[0])}, ${f(w[1])}, ${f(w[2])}) * ${f(dim)};
    fragColor = vec4(clamp(c, 0.0, 1.0), px.a);
}
`;
        flip = !flip;
        shaderFile.path = runDir + "/screen-" + (flip ? "a" : "b") + ".frag";
        shaderFile.setText(src);
    }
    FileView {
        id: shaderFile
        printErrors: false
        onSaved: {
            root.applied = true;
            Hypr.hyprEval(`hl.config({ decoration = { screen_shader = ${JSON.stringify(path)} } })`);
        }
        onSaveFailed: err => console.warn("altair: cannot write the screen shader: " + FileViewError.toString(err))
    }

    // A config reload puts back the config's screen_shader: re-apply ours.
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "configreloaded" && root.applied) {
                root.applied = false;
                root.scheduleApply();
            }
        }
    }
}
