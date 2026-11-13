// SPDX-License-Identifier: GPL-3.0-or-later
#version 440

// Liquid-glass surface for Altair panels (used by components/GlassBackground.qml).
//
// What it draws, all on our own panel (the blur behind it comes from the
// compositor; real refraction of the background is not possible):
//   - a vertical tint gradient (lighter at the top, as if lit from above)
//   - a soft inner glow just inside the edge
//   - a thin specular rim, brightest where the edge faces the light (top-left),
//     in the palette's light colour (pure white clashed with tinted palettes)
//   - slight darkening toward the bottom edge, for depth
//
// Nothing here depends on time: it is rendered when the item repaints, never
// continuously.
//
// Rebuild after editing:  scripts/build-shaders.sh

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;          // item size in pixels
    float radius;       // corner radius in pixels
    float rimStrength;  // 0..1
    vec4 topTint;       // straight (non-premultiplied) rgba
    vec4 bottomTint;
    vec4 rimColor;      // straight rgb; alpha unused
};

// Signed distance to a rounded box centred at the origin (< 0 inside).
float sdRoundBox(vec2 p, vec2 halfSize, float r) {
    vec2 q = abs(p) - halfSize + vec2(r);
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void main() {
    vec2 p = qt_TexCoord0 * size - size * 0.5;
    float d = sdRoundBox(p, size * 0.5, radius);
    float coverage = clamp(0.5 - d, 0.0, 1.0);               // 1 px anti-aliased edge

    // Body tint.
    vec4 tint = mix(topTint, bottomTint, smoothstep(0.0, 1.0, qt_TexCoord0.y));
    vec3 rgb = tint.rgb * tint.a;                             // premultiply
    float a = tint.a;

    // 0 at the edge, 1 from ~16 px inside.
    float inner = clamp(-d / 16.0, 0.0, 1.0);

    // Light: inner glow (white) + specular rim (rimColor), added over the tint.
    float glow = pow(1.0 - inner, 3.0) * 0.08;
    vec2 n = normalize(p / (size * 0.5) + vec2(1e-4));
    float facing = clamp(dot(n, normalize(vec2(-0.35, -1.0))), 0.0, 1.0);
    float band = clamp(1.0 - abs(d + 1.0), 0.0, 1.0);        // ~2 px line, 1 px inside
    float rim = band * (0.08 + 0.55 * facing) * rimStrength;
    float light = clamp(glow + rim, 0.0, 1.0);
    vec3 lightRgb = (vec3(glow) + rimColor.rgb * rim) / max(glow + rim, 1e-4);
    rgb = rgb * (1.0 - light) + lightRgb * light;
    a = a + light * (1.0 - a);

    // Depth: darken toward the bottom inner edge.
    float shade = (1.0 - inner) * smoothstep(0.55, 1.0, qt_TexCoord0.y) * 0.10;
    rgb *= (1.0 - shade);
    a = a + shade * (1.0 - a);

    fragColor = vec4(rgb, a) * coverage * qt_Opacity;
}
