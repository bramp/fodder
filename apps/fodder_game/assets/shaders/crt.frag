#version 460 core

#include <flutter/runtime_effect.glsl>

uniform float uTime;
uniform vec2 uSize;

out vec4 fragColor;

// Pseudo-random function for noise
float random(vec2 uv) {
    return fract(sin(dot(uv, vec2(12.9898, 78.233))) * 43758.5453);
}

void main() {
    vec2 pos = FlutterFragCoord().xy;
    vec2 uv = pos / uSize;

    // --- 1. Scanlines ---
    // Since logical pixels are 2x larger, we align scanlines to logical pixel rows.
    // Period is 2.0 screen pixels.
    float scanline = 0.88 + 0.12 * sin(pos.y * 1.570796); // PI/2 frequency

    // --- 2. RGB sub-pixel mask ---
    // Mimics the aperture grille. Repeating every 3 logical pixels (6 screen pixels).
    float mask = 0.92 + 0.08 * sin(pos.x * 0.523598); // PI/6 frequency

    // --- 3. Screen Curvature & Vignette ---
    // Gives that classic "bulge" look without actually warping pixels.
    vec2 centeredUv = (uv - 0.5) * 2.0;
    float dist = dot(centeredUv, centeredUv);

    // Vignette: Darkens the edges more subtly (pushed range out)
    float vignette = 1.0 - smoothstep(1.2, 2.0, dist);

    // --- 4. Phosphor Noise ---
    // Subtle film grain/phosphor noise
    float noise = (random(uv + uTime * 0.1) - 0.5) * 0.04;

    // Combine all effects into a modulation factor
    // vignette * mask * scanline creates the base CRT look
    vec3 modulation = vec3(vignette * mask * scanline);

    // Add noise on top
    vec3 result = modulation + noise;

    // Clamp for stability but keep the range for modulation
    fragColor = vec4(result, 1.0);
}
