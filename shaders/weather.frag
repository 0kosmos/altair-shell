// SPDX-License-Identifier: GPL-3.0-or-later
#version 440

// Moving weather behind the Weather widget (widgets/WeatherEffect.qml):
//   mode 1  rain: slanted streaks in a few depth layers
//   mode 2  snow: soft round flakes that sway while falling
// plus `flash` (0..1) for thunderstorms. Everything is computed from `time`,
// so the CPU only updates one number per frame (the item updates `time`
// ~24 times a second while it is visible). Clipped to the widget's rounded
// corners.
//
// Rebuild after editing:  scripts/build-shaders.sh

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;        // item size in pixels
    float radius;     // corner radius in pixels
    float time;       // seconds
    float mode;       // 1 rain, 2 snow
    float amount;     // 0..1 (drizzle .. heavy)
    float flash;      // 0..1 lightning
    vec4 tint;        // straight rgb of the drops/flakes
};

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Rounded-rectangle coverage (1 inside, 0 outside, ~1 px soft edge).
float roundedMask(vec2 px) {
    vec2 h = size * 0.5;
    vec2 q = abs(px - h) - (h - vec2(radius));
    float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
    return clamp(0.5 - d, 0.0, 1.0);
}

// One layer of rain: columns `cell` px wide, one streak per column, falling
// at `speed` px/s, slanted.
float rainLayer(vec2 px, float cell, float speed, float len, float seed) {
    float slant = 0.22;
    vec2 p = px;
    p.x += p.y * slant;                         // shear: streaks lean left
    float col = floor(p.x / cell);
    float r = hash(vec2(col, seed));
    if (r > 0.35 + 0.6 * amount)                // fewer streaks in drizzle
        return 0.0;
    float period = size.y + len * 2.0;
    float y = mod(p.y - time * speed * (0.8 + 0.4 * r) - r * period, period) - len;
    float x = abs(p.x - (col + 0.5) * cell);
    float along = clamp(1.0 - abs(y) / len, 0.0, 1.0);   // streak body
    float across = clamp(1.0 - x / 0.9, 0.0, 1.0);      // ~1 px wide
    return along * across * (0.45 + 0.4 * r);
}

// One layer of snow: a flake per cell, falling and swaying.
float snowLayer(vec2 px, float cell, float speed, float size0, float seed) {
    vec2 p = px;
    p.y -= time * speed;
    vec2 id = floor(p / cell);
    float r = hash(id + seed);
    if (r > 0.25 + 0.6 * amount)
        return 0.0;
    vec2 c = (id + vec2(0.5 + 0.3 * sin(time * 0.9 + r * 6.28), 0.5)) * cell;
    float d = length(p - c);
    float s = size0 * (0.7 + 0.6 * r);
    return smoothstep(s, s * 0.35, d) * (0.5 + 0.4 * r);
}

void main() {
    vec2 px = qt_TexCoord0 * size;
    float a = 0.0;
    if (mode < 1.5) {
        a += rainLayer(px, 9.0, 260.0, 9.0, 1.0);
        a += rainLayer(px + vec2(4.0, 0.0), 13.0, 330.0, 13.0, 2.0) * 0.8;
    } else {
        a += snowLayer(px, 26.0, 16.0, 2.6, 3.0);
        a += snowLayer(px + vec2(11.0, 7.0), 17.0, 10.0, 1.7, 4.0) * 0.7;
    }
    a = clamp(a, 0.0, 1.0) * 0.55;
    vec3 col = tint.rgb * a;                      // premultiplied
    float fl = flash * 0.16;
    col += vec3(fl);
    float alpha = max(a, fl);
    float m = roundedMask(px) * qt_Opacity;
    fragColor = vec4(col, alpha) * m;
}
