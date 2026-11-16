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
// Static: nothing depends on time, it is only drawn when the panel itself
// redraws. Clipped to the panel's rounded corners.
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
    float strength;   // 0..1, lower on light themes
    vec4 accent;      // straight rgb
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
        vec3 c2 = clamp(hueShift(accent.rgb, 0.9), 0.0, 1.0);
        vec3 c3 = clamp(hueShift(accent.rgb, -0.8), 0.0, 1.0);
        float b1 = blob(px, vec2(size.x * 0.15, size.y * 0.05), m * 0.55);
        float b2 = blob(px, vec2(size.x * 0.85, size.y * 0.35), m * 0.5);
        float b3 = blob(px, vec2(size.x * 0.45, size.y * 1.05), m * 0.55);
        float sum = b1 + b2 + b3 + 1e-4;
        col = (c1 * b1 + c2 * b2 + c3 * b3) / sum;
        a = clamp(sum, 0.0, 1.0) * 0.20 * strength;
    } else if (mode < 3.5) {
        float n = hash(floor(px)) - 0.5;
        col = n > 0.0 ? vec3(1.0) : vec3(0.0);
        a = abs(n) * 0.10 * strength;
    } else if (mode < 4.5) {
        // Mesh: bilinear blend of four colours, one per corner.
        vec2 uv = px / size;
        vec3 c00 = accent.rgb;
        vec3 c10 = clamp(hueShift(accent.rgb, 1.2), 0.0, 1.0);
        vec3 c01 = clamp(hueShift(accent.rgb, -1.0), 0.0, 1.0);
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
        col = mix(accent.rgb, clamp(hueShift(accent.rgb, -1.4), 0.0, 1.0), t);
        a = (0.10 + 0.10 * t) * strength;
    } else if (mode < 8.5) {
        // Lines: 1 px diagonal stripes every 7 px, antialiased.
        float s = mod(px.x + px.y, 7.0);
        float l = clamp(1.0 - abs(s - 0.5) * 1.2, 0.0, 1.0);
        col = vec3(1.0);
        a = l * 0.045 * strength;
    } else {
        // Dots: a 12 px grid of soft dots.
        vec2 c = mod(px, 12.0) - 6.0;
        float d = clamp(1.6 - length(c), 0.0, 1.0);
        col = vec3(1.0);
        a = d * 0.09 * strength;
    }

    float k = roundedMask(px) * qt_Opacity;
    fragColor = vec4(col * a, a) * k;
}
