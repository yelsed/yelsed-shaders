// Retro Post-Processing: Chromatic Aberration + Film Grain
// Stack after other shaders in Ghostty config for additional retro feel.

// ── User-configurable constants ─────────────────────────────────────────
float CA_STRENGTH  = 0.003;  // chromatic aberration intensity (0.0 = off)
float GRAIN_AMOUNT = 0.06;   // noise/grain intensity (0.0 = off)

// ── Noise hash ──────────────────────────────────────────────────────────
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

// ── Main ────────────────────────────────────────────────────────────────
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;

    // Chromatic aberration: offset increases toward screen edges
    vec2 centered = uv - 0.5;
    float dist = length(centered);
    vec2 offset = centered * dist * CA_STRENGTH;

    float r = texture(iChannel0, uv - offset).x;
    float g = texture(iChannel0, uv).y;
    float b = texture(iChannel0, uv + offset).z;
    vec3 color = vec3(r, g, b);

    // Animated film grain
    float noise = hash(uv * iResolution.xy + vec2(iTime * 100.0, iTime * 57.0));
    noise = (noise - 0.5) * GRAIN_AMOUNT;
    color += vec3(noise);

    fragColor.xyz = color;
    fragColor.w = 1.0;
}
