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
    // Horizontal dark lines that move slightly with the screen's refresh
    float scanlineFreq = uSize.y * 1.5;
    float scanline = 0.88 + 0.12 * sin(uv.y * scanlineFreq + uTime * 0.5);

    // --- 2. RGB sub-pixel mask ---
    // Mimics the aperture grille of a high-end Sony Trinitron
    float maskFreq = uSize.x * 3.0;
    float mask = 0.92 + 0.08 * sin(uv.x * maskFreq);

    // --- 3. Screen Curvature & Vignette ---
    // Gives that classic "bulge" look without actually warping pixels (since we don't have the sampler)
    vec2 centeredUv = (uv - 0.5) * 2.0;
    float dist = dot(centeredUv, centeredUv);

    // Vignette: Darkens the edges
    float vignette = 1.0 - smoothstep(0.85, 1.6, dist);

    // --- 4. Retro Flicker & Rolling Bar ---
    // A subtle rolling brightness change typical of phosphor persistence
    float rollingBar = 0.02 * sin(uv.y * 5.0 - uTime * 3.0);
    float flicker = 1.0 + 0.005 * sin(uTime * 60.0) + rollingBar;

    // --- 5. Phosphor Noise ---
    // Subtle film grain/phosphor noise
    float noise = (random(uv + uTime * 0.1) - 0.5) * 0.03;

    // --- 6. Glass Reflection ---
    // A very subtle diagonal highlight to simulate ambient light on the glass screen
    float reflectAngle = uv.x + uv.y;
    float reflection = 0.03 * smoothstep(0.45, 0.55, abs(reflectAngle - 1.0 + 0.05 * sin(uTime * 0.2)));

    // Combine all effects into a modulation factor
    // vignette * mask * scanline * flicker creates the base CRT look
    vec3 modulation = vec3(vignette * mask * scanline * flicker);

    // Add noise and reflection on top
    vec3 result = modulation + noise + reflection;

    // Since we use BlendMode.modulate, the result should mostly be in the 0.0-1.2 range.
    // Values < 1 darkens, > 1 brightens.
    fragColor = vec4(result, 1.0);
}
