// SPDX-License-Identifier: GPL-3.0-or-later
#version 440

// Decoration on top of Altair's panel backgrounds (components/GlassBackground
// .qml, Settings > Effects > Panel backgrounds):
//   mode 1  glow    soft accent light from the top-left corner
//   mode 2  aurora  three soft colour clouds from the accent (hue-shifted)
//   mode 3  grain   fine static film grain, like frosted glass
//   mode 4  mesh    four soft colour corners (accent and its neighbours)
//   mode 5  sheen   a glossy diagonal light band, like polished glass
//   mode 6  edge    accent light along the top edge, fading down
//   mode 7  dusk    vertical blend from the accent to a warmer hue
//   mode 8  lines   fine diagonal pinstripes
//   mode 9  dots    a faint dot grid
// Animated (only while a panel is open, `time` advanced by the item at
// 30 fps; anywhere else time stays put and they are a still frame):
//   mode 10 flow    aurora clouds that drift and swirl
//   mode 11 nebula  soft value-noise mist drifting sideways
//   mode 12 waves   slow layered light waves
//   mode 13 prism   an iridescent band sweeping across
//   mode 14 stars   faint stars that twinkle
//   mode 15 pulse   accent light breathing along the edges
//   mode 16 lava    soft blobs that merge and part (metaballs)
//   mode 17 ripple  slow rings spreading from a corner
//   mode 18 snow    small flakes falling and swaying
//   mode 19 plasma  shifting bands of colour
// Static modes ignore `time`. Colours: c2/c3 are a second and third colour
// (from the palette); with alpha 0 they are derived from the accent.
// Clipped to the panel's rounded corners.
//
// Rebuild after editing:  scripts/build-shaders.sh

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;        // item size in pixels
    float radius;     // corner radius in pixels
    float mode;
    float strength;   // 0..~1.6: theme (lower on light) × intensity setting
    float time;       // seconds × speed (animated modes)
    vec4 accent;      // straight rgb
    vec4 c2;          // second colour (a = 0: derive from the accent)
    vec4 c3;          // third colour
};

float roundedMask(vec2 px) {
    vec2 h = size * 0.5;
    vec2 q = abs(px - h) - (h - vec2(radius));
    float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
    return clamp(0.5 - d, 0.0, 1.0);
}

vec3 hueShift(vec3 c, float a) {
    // Rotation around the grey axis (cheap hue shift).
    const vec3 k = vec3(0.57735);
    float ca = cos(a);
    return c * ca + cross(k, c) * sin(a) + k * dot(k, c) * (1.0 - ca);
}

float blob(vec2 px, vec2 c, float r) {
    float d = length(px - c) / r;
    return exp(-d * d * 2.2);
}

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float vnoise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x),
               mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}

float fbm(vec2 p) {
    float v = 0.0, a = 0.5;
    for (int i = 0; i < 4; i++) {
        v += a * vnoise(p);
        p = p * 2.03 + vec2(1.7, 9.2);
        a *= 0.5;
    }
    return v;
}

vec3 second() { return c2.a > 0.0 ? c2.rgb : clamp(hueShift(accent.rgb, 0.9), 0.0, 1.0); }
vec3 third() { return c3.a > 0.0 ? c3.rgb : clamp(hueShift(accent.rgb, -0.8), 0.0, 1.0); }

void main() {
    vec2 px = qt_TexCoord0 * size;
    float m = max(size.x, size.y);
    vec3 col = vec3(0.0);
    float a = 0.0;

    if (mode < 1.5) {
        float g = blob(px, vec2(0.0), m * 0.75);
        float g2 = blob(px, size, m * 0.5) * 0.35;
        a = (g + g2) * 0.20 * strength;
        col = accent.rgb;
    } else if (mode < 2.5) {
        vec3 c1 = accent.rgb;
        vec3 k2 = second();
        vec3 k3 = third();
        float b1 = blob(px, vec2(size.x * 0.15, size.y * 0.05), m * 0.55);
        float b2 = blob(px, vec2(size.x * 0.85, size.y * 0.35), m * 0.5);
        float b3 = blob(px, vec2(size.x * 0.45, size.y * 1.05), m * 0.55);
        float sum = b1 + b2 + b3 + 1e-4;
        col = (c1 * b1 + k2 * b2 + k3 * b3) / sum;
        a = clamp(sum, 0.0, 1.0) * 0.20 * strength;
    } else if (mode < 3.5) {
        float n = hash(floor(px)) - 0.5;
        col = n > 0.0 ? vec3(1.0) : vec3(0.0);
        a = abs(n) * 0.10 * strength;
    } else if (mode < 4.5) {
        // Mesh: bilinear blend of four colours, one per corner.
        vec2 uv = px / size;
        vec3 c00 = accent.rgb;
        vec3 c10 = c2.a > 0.0 ? c2.rgb : clamp(hueShift(accent.rgb, 1.2), 0.0, 1.0);
        vec3 c01 = c3.a > 0.0 ? c3.rgb : clamp(hueShift(accent.rgb, -1.0), 0.0, 1.0);
        vec3 c11 = clamp(hueShift(accent.rgb, 2.4), 0.0, 1.0);
        col = mix(mix(c00, c10, uv.x), mix(c01, c11, uv.x), uv.y);
        a = 0.22 * strength;
    } else if (mode < 5.5) {
        // Sheen: a soft bright band across, top-left to bottom-right.
        vec2 uv = px / m;
        float d = (uv.x + uv.y * 0.6) - 0.35;
        float band = exp(-d * d * 40.0) + 0.45 * exp(-(d - 0.12) * (d - 0.12) * 260.0);
        col = vec3(1.0);
        a = band * 0.09 * strength;
    } else if (mode < 6.5) {
        // Edge light: strong at the top, a little at the sides.
        float top = exp(-px.y / 14.0);
        float sides = exp(-min(px.x, size.x - px.x) / 10.0) * exp(-px.y / (size.y * 0.5)) * 0.5;
        col = accent.rgb;
        a = clamp(top + sides, 0.0, 1.0) * 0.45 * strength;
    } else if (mode < 7.5) {
        // Dusk: accent at the top into a warmer neighbour at the bottom.
        float t = px.y / size.y;
        col = mix(accent.rgb, c3.a > 0.0 ? c3.rgb : clamp(hueShift(accent.rgb, -1.4), 0.0, 1.0), t);
        a = (0.10 + 0.10 * t) * strength;
    } else if (mode < 8.5) {
        // Lines: 1 px diagonal stripes every 7 px, antialiased.
        float s = mod(px.x + px.y, 7.0);
        float l = clamp(1.0 - abs(s - 0.5) * 1.2, 0.0, 1.0);
        col = vec3(1.0);
        a = l * 0.045 * strength;
    } else if (mode < 9.5) {
        // Dots: a 12 px grid of soft dots.
        vec2 c = mod(px, 12.0) - 6.0;
        float d = clamp(1.6 - length(c), 0.0, 1.0);
        col = vec3(1.0);
        a = d * 0.09 * strength;
    } else if (mode < 10.5) {
        // Flow: three clouds circling slowly, each on its own path.
        float t = time * 0.25;
        vec2 p1 = size * vec2(0.25 + 0.20 * sin(t), 0.20 + 0.15 * cos(t * 0.8));
        vec2 p2 = size * vec2(0.75 + 0.18 * cos(t * 0.7 + 1.0), 0.45 + 0.25 * sin(t * 0.9));
        vec2 p3 = size * vec2(0.50 + 0.25 * sin(t * 0.6 + 2.0), 0.95 + 0.10 * cos(t * 1.1));
        float b1 = blob(px, p1, m * 0.55), b2 = blob(px, p2, m * 0.5), b3 = blob(px, p3, m * 0.55);
        float sum = b1 + b2 + b3 + 1e-4;
        col = (accent.rgb * b1 + second() * b2 + third() * b3) / sum;
        a = clamp(sum, 0.0, 1.0) * 0.34 * strength;
    } else if (mode < 11.5) {
        // Nebula: two layers of soft noise drifting at different speeds.
        vec2 uv = px / 140.0;
        float n1 = fbm(uv + vec2(time * 0.05, 0.0));
        float n2 = fbm(uv * 1.7 - vec2(time * 0.03, time * 0.02) + 5.0);
        col = mix(accent.rgb, second(), smoothstep(0.3, 0.7, n2));
        a = smoothstep(0.3, 0.8, n1) * 0.40 * strength;
    } else if (mode < 12.5) {
        // Waves: three soft bands of light, rolling.
        float w = 0.0;
        for (int i = 0; i < 3; i++) {
            float fi = float(i);
            float y = size.y * (0.35 + 0.22 * fi)
                + sin(px.x / (90.0 + 30.0 * fi) + time * (0.5 + 0.2 * fi) + fi * 2.0) * (14.0 + 6.0 * fi);
            float d = (px.y - y) / (24.0 + 10.0 * fi);
            w += exp(-d * d) * (0.8 - 0.2 * fi);
        }
        col = mix(accent.rgb, second(), px.y / size.y);
        a = clamp(w, 0.0, 1.0) * 0.42 * strength;
    } else if (mode < 13.5) {
        // Prism: a wide rainbow-tinted band sliding across, then again.
        vec2 uv = px / m;
        float pos = fract(time * 0.06) * 2.6 - 0.8;
        float d = (uv.x + uv.y * 0.5) - pos;
        float band = exp(-d * d * 9.0);
        col = clamp(hueShift(accent.rgb, d * 6.0 + time * 0.2), 0.0, 1.0);
        a = band * 0.28 * strength;
    } else if (mode < 14.5) {
        // Stars: one possible star per 22 px cell, twinkling at its own pace,
        // the whole sky drifting slowly.
        vec2 sp = px + vec2(time * 4.0, time * 1.5);
        vec2 cell = floor(sp / 22.0);
        float h = hash(cell);
        vec2 c = (cell + 0.25 + 0.5 * vec2(hash(cell + 3.1), hash(cell + 7.7))) * 22.0;
        float d = length(sp - c);
        float on = step(0.62, h);
        float tw = 0.5 + 0.5 * sin(time * (1.0 + 2.0 * h) + h * 40.0);
        float star = clamp(1.8 - d, 0.0, 1.0) + exp(-d * d * 0.08) * 0.5;
        col = mix(vec3(1.0), accent.rgb, 0.4);
        a = on * star * tw * 0.7 * strength;
    } else if (mode < 15.5) {
        // Pulse: edge light that breathes, brighter at the top.
        float e = min(min(px.x, size.x - px.x), min(px.y, size.y - px.y));
        float edge = exp(-e / 22.0) * (0.6 + 0.4 * exp(-px.y / (size.y * 0.6)));
        float breath = 0.55 + 0.45 * sin(time * 1.2);
        col = mix(accent.rgb, second(), 0.5 + 0.5 * sin(time * 0.4));
        a = edge * breath * 0.60 * strength;
    } else if (mode < 16.5) {
        // Lava: five blobs on slow orbits; their summed field, thresholded
        // softly, looks like blobs merging and splitting.
        float f = 0.0;
        vec3 c = vec3(0.0);
        for (int i = 0; i < 5; i++) {
            float fi = float(i);
            vec2 o = size * vec2(0.5 + 0.38 * sin(time * (0.21 + 0.05 * fi) + fi * 1.7),
                                 0.5 + 0.38 * cos(time * (0.17 + 0.04 * fi) + fi * 2.3));
            float r = m * (0.13 + 0.03 * fi);
            float v = r * r / (dot(px - o, px - o) + 1.0);
            f += v;
            c += v * (i == 0 || i == 3 ? accent.rgb : i == 1 || i == 4 ? second() : third());
        }
        col = c / max(f, 1e-4);
        a = smoothstep(0.55, 1.1, f) * 0.30 * strength + smoothstep(0.15, 0.6, f) * 0.06 * strength;
    } else if (mode < 17.5) {
        // Ripple: rings from the top-left corner, spreading and fading.
        float d = length(px) / 34.0 - time * 0.9;
        float ring = pow(0.5 + 0.5 * sin(d * 6.2831), 6.0);
        float fade = exp(-length(px) / (m * 0.8));
        col = mix(accent.rgb, second(), 0.5 + 0.5 * sin(d * 0.7));
        a = ring * fade * 0.30 * strength;
    } else if (mode < 18.5) {
        // Snow: three layers of flakes (far = small and slow).
        float sn = 0.0;
        for (int i = 0; i < 3; i++) {
            float fi = float(i);
            float cs = 26.0 + 12.0 * fi;
            vec2 q = px + vec2(sin(time * 0.6 + px.y / 60.0 + fi) * 6.0, -time * (10.0 + 9.0 * fi));
            vec2 cell = floor(q / cs);
            float h = hash(cell + fi * 13.0);
            vec2 c = (cell + 0.2 + 0.6 * vec2(hash(cell + 2.3 + fi), hash(cell + 5.9 + fi))) * cs;
            float d = length(q - c);
            sn += step(0.45, h) * clamp((1.0 + fi * 0.6) - d, 0.0, 1.0) * (0.5 + 0.25 * fi);
        }
        col = mix(vec3(1.0), accent.rgb, 0.25);
        a = clamp(sn, 0.0, 1.0) * 0.55 * strength;
    } else {
        // Plasma: classic sum of sines, mapped between the three colours.
        vec2 uv = px / m * 3.0;
        float v = sin(uv.x + time * 0.5) + sin(uv.y * 1.3 - time * 0.4)
                + sin((uv.x + uv.y) * 0.8 + time * 0.3) + sin(length(uv - 1.5) * 1.6 - time * 0.6);
        float t = 0.5 + 0.125 * v;
        col = t < 0.5 ? mix(accent.rgb, second(), t * 2.0) : mix(second(), third(), t * 2.0 - 1.0);
        a = (0.12 + 0.10 * sin(v * 1.5)) * strength;
    }

    float k = roundedMask(px) * qt_Opacity;
    fragColor = vec4(col * a, a) * k;
}
