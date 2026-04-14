// Nokia 3310 LCD Post-Processing Shader
// Green LCD color grading with barrel distortion.
// Place AFTER the logo shader in Ghostty config.

// ── User-configurable constants ─────────────────────────────────────────
float GREEN_TINT  = 0.40;   // Nokia green strength (0.0 = original, 1.0 = full green)
float WARP        = 0.03;   // barrel distortion strength (0.0 = flat)

vec3 LCD_LIGHT = vec3(0.61, 0.74, 0.06);  // #9bbc0f
vec3 LCD_DARK  = vec3(0.06, 0.22, 0.06);  // #0f380f

// ── Barrel distortion ───────────────────────────────────────────────────
vec2 barrelDistort(vec2 uv) {
    vec2 centered = uv - 0.5;
    float r2 = dot(centered, centered);
    centered *= 1.0 + WARP * r2;
    return centered + 0.5;
}

// ── Main ────────────────────────────────────────────────────────────────
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    vec2 warped = barrelDistort(uv);
    vec3 src = texture(iChannel0, warped).xyz;

    // Nokia green color grading
    float lum = dot(src, vec3(0.299, 0.587, 0.114));
    vec3 nokia = mix(LCD_DARK, LCD_LIGHT, lum);
    vec3 color = mix(src, nokia, GREEN_TINT);

    fragColor.xyz = color;
    fragColor.w = 1.0;
}
