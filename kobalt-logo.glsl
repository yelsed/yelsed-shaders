// Kobalt Logo Background Shader
// Renders the Kobalt icon as a centered watermark behind terminal content.
// Place BEFORE tft.glsl in Ghostty config so scanlines apply over it.

// ── User-configurable constants ─────────────────────────────────────────
const float LOGO_SCALE    = 0.15;   // size relative to screen height
const float LOGO_OPACITY  = 0.35;   // base opacity
const float PULSE_SPEED   = 1.5;    // breathing animation speed
const float PULSE_AMOUNT  = 0.08;   // opacity oscillation range
const vec3  LOGO_COLOR    = vec3(0.949, 0.278, 0.145); // #F24725

// ── SDF helpers ─────────────────────────────────────────────────────────

// Half-circle SDF: circle intersected with half-plane x <= cutX
// (flat edge on right, curve bulging left)
float sdHalfCircle(vec2 p, vec2 center, float radius, float cutX) {
    float circle = length(p - center) - radius;
    float plane  = p.x - cutX;
    return max(circle, plane);
}

// Kobalt icon SDF: union of two left-facing half-circles
// Geometry from kobalt.svg (viewBox 0 0 141 25), normalized to unit height,
// origin at bounding-box center.
float kobaltSDF(vec2 p) {
    // Precise coords from kobalt.svg, y-flipped for GLSL (y-up)
    float large = sdHalfCircle(p, vec2( 0.047, 0.0),    0.467, 0.047);
    float small = sdHalfCircle(p, vec2( 0.420, -0.085),  0.377, 0.420);
    return min(large, small);
}

// ── Main ────────────────────────────────────────────────────────────────

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec4 terminal = texture(iChannel0, uv);

    // Aspect-corrected centered coordinates, scaled by LOGO_SCALE
    float aspect = iResolution.x / iResolution.y;
    vec2 p = (uv - 0.5) * vec2(aspect, -1.0) / LOGO_SCALE;

    // Evaluate SDF with anti-aliased edge
    float dist  = kobaltSDF(p);
    float pixel = 1.0 / (iResolution.y * LOGO_SCALE);
    float shape = 1.0 - smoothstep(-pixel, pixel, dist);

    // Soft glow: exponential falloff outside the shape
    float glow = exp(-4.0 * max(dist, 0.0));
    shape = max(shape, glow * 0.3);

    // Breathing pulse
    float pulse = LOGO_OPACITY + PULSE_AMOUNT * sin(iTime * PULSE_SPEED);

    // Dark mask: logo only visible in dark/empty areas
    float luminance = dot(terminal.rgb, vec3(0.299, 0.587, 0.114));
    float darkMask  = 1.0 - smoothstep(0.05, 0.4, luminance);

    // Composite
    vec3 result = mix(terminal.rgb, LOGO_COLOR, shape * pulse * darkMask);
    fragColor = vec4(result, terminal.a);
}
