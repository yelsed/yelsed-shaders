// Kobalt Logo 3D ASCII Art Shader — Glowing Border Edition
// Renders the Kobalt icon as a 3D extruded model displayed with ASCII characters,
// with a bright yellow animated border and a "spin-in" deceleration on tab open.
// Place BEFORE tft.glsl in Ghostty config.
//
// SVG source: kobalt.svg — to use a different logo, update kobaltSDF2D().

// ── User-configurable constants ─────────────────────────────────────────
const float LOGO_SCALE      = 0.30;    // size relative to screen height
const float LOGO_OPACITY    = 0.35;    // base opacity
const float ROTATION_SPEED  = -0.4;    // radians per second (negative = reverse)
const float EXTRUDE_DEPTH   = 0.15;    // Z extrusion half-depth
const vec3  LOGO_COLOR      = vec3(0.949, 0.278, 0.145); // #F24725
const float CELL_SIZE       = 8.0;     // pixel size of each ASCII cell
const bool  OSCILLATE       = false;   // true = rock back and forth, false = continuous spin
const float OSCILLATE_RANGE = 0.8;     // max angle in radians when oscillating
const float ROUND_RADIUS    = 0.02;    // rounding to soften edges

// ── Border constants ────────────────────────────────────────────────────
const vec3  BORDER_COLOR       = vec3(1.0, 0.95, 0.0);  // bright yellow
const float BORDER_WIDTH       = 0.04;                    // SDF units for border thickness
const float BORDER_SPEED       = 2.0;                     // vertical sweep speed
const float BORDER_PULSE_SPEED = 3.0;                     // pulsation frequency
const float BORDER_INTENSITY   = 1.0;                     // max brightness

// ── Spin-in constants ───────────────────────────────────────────────────
const float SPIN_DECEL_RATE = 0.7;   // exponential decay rate (lower = longer spin-in)
const float SPIN_BOOST      = 14.0;  // initial speed multiplier minus 1 (15x total)

// ── ASCII character set ─────────────────────────────────────────────────
// 10 density levels: " .:-=+*#%@"
// Each character is a 4x6 bitmap packed into 24 bits (stored as int).
// Bit layout: row 0 (top) is bits 0-3, row 1 is bits 4-7, etc.

int ASCII_CHARS[10] = int[10](
    // ' ' (space) - empty
    0x000000,
    // '.' - single dot bottom center
    0x000600,
    // ':' - two dots
    0x006006,
    // '-' - horizontal bar mid
    0x000F00,
    // '=' - two horizontal bars
    0x0F00F0,
    // '+' - cross
    0x046E46,
    // '*' - star pattern
    0x069F96,
    // '#' - hash/dense grid
    0x69F69F,
    // '%' - percent-like dense
    0x936C93,
    // '@' - nearly full
    0x6F9F9F
);

// Look up a pixel in a 4x6 bitmap
float charPixel(int bitmap, vec2 cellUV) {
    int col = int(cellUV.x * 4.0);
    int row = int(cellUV.y * 6.0);
    col = clamp(col, 0, 3);
    row = clamp(row, 0, 5);
    int bitIndex = row * 4 + col;
    return float((bitmap >> bitIndex) & 1);
}

// ── SDF helpers ─────────────────────────────────────────────────────────

// Half-circle SDF: circle intersected with half-plane x <= cutX
float sdHalfCircle(vec2 p, vec2 center, float radius, float cutX) {
    float circle = length(p - center) - radius;
    float plane  = p.x - cutX;
    return max(circle, plane);
}

// Kobalt icon 2D SDF (from kobalt.svg)
float kobaltSDF2D(vec2 p) {
    float large = sdHalfCircle(p, vec2( 0.047, 0.0),   0.467, 0.047);
    float small = sdHalfCircle(p, vec2( 0.420,-0.085),  0.377, 0.420);
    return min(large, small);
}

// Extrude 2D SDF into 3D along Z
float kobaltSDF3D(vec3 p) {
    float d2d = kobaltSDF2D(p.xy);
    float dz  = abs(p.z) - EXTRUDE_DEPTH;
    // Standard extrusion: max of 2D shape and Z slab
    float d = min(max(d2d, dz), length(max(vec2(d2d, dz), 0.0)));
    return d - ROUND_RADIUS; // rounding
}

// ── Rotation ────────────────────────────────────────────────────────────

mat3 rotateY(float angle) {
    float c = cos(angle);
    float s = sin(angle);
    return mat3(
        c, 0.0, s,
        0.0, 1.0, 0.0,
       -s, 0.0, c
    );
}

// ── Ray marching ────────────────────────────────────────────────────────

const int   MAX_STEPS = 64;
const float MAX_DIST  = 5.0;
const float SURF_DIST = 0.001;

struct MarchResult {
    float dist;
    bool  hit;
};

MarchResult rayMarch(vec3 ro, vec3 rd, mat3 rot) {
    float t = 0.0;
    for (int i = 0; i < MAX_STEPS; i++) {
        vec3 p = ro + rd * t;
        vec3 rp = rot * p; // rotate sample point
        float d = kobaltSDF3D(rp);
        if (d < SURF_DIST) return MarchResult(t, true);
        t += d;
        if (t > MAX_DIST) break;
    }
    return MarchResult(t, false);
}

// Surface normal via finite differences
vec3 getNormal(vec3 p, mat3 rot) {
    const float e = 0.001;
    vec3 rp = rot * p;
    float d = kobaltSDF3D(rp);
    return normalize(vec3(
        kobaltSDF3D(rot * (p + vec3(e,0,0))) - d,
        kobaltSDF3D(rot * (p + vec3(0,e,0))) - d,
        kobaltSDF3D(rot * (p + vec3(0,0,e))) - d
    ));
}

// ── Main ────────────────────────────────────────────────────────────────

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec4 terminal = texture(iChannel0, uv);

    // ── ASCII cell coordinates ──────────────────────────────────────
    vec2 cellIndex = floor(fragCoord / CELL_SIZE);
    vec2 cellCenter = (cellIndex + 0.5) * CELL_SIZE;
    vec2 cellUV = fract(fragCoord / CELL_SIZE); // position within cell [0,1)

    // ── Orthographic camera from cell center ────────────────────────
    float aspect = iResolution.x / iResolution.y;
    vec2 ndc = (cellCenter / iResolution.xy - 0.5) * vec2(aspect, -1.0);
    vec2 p2d = ndc / LOGO_SCALE;

    vec3 ro = vec3(p2d, -2.0); // ray origin (far back)
    vec3 rd = vec3(0.0, 0.0, 1.0); // parallel rays along +Z

    // ── Spin-in rotation: starts 10x fast, decelerates to normal ────
    // Integrated angle = ROTATION_SPEED * (t + SPIN_BOOST/SPIN_DECEL_RATE * (1 - exp(-t * SPIN_DECEL_RATE)))
    float t = iTime;
    float angle;
    if (OSCILLATE) {
        angle = sin(t * ROTATION_SPEED) * OSCILLATE_RANGE;
    } else {
        angle = ROTATION_SPEED * (t + SPIN_BOOST / SPIN_DECEL_RATE * (1.0 - exp(-t * SPIN_DECEL_RATE)));
    }
    mat3 rot = rotateY(angle);

    // ── Ray march ───────────────────────────────────────────────────
    MarchResult mr = rayMarch(ro, rd, rot);

    float intensity = 0.0;
    if (mr.hit) {
        vec3 hitPos = ro + rd * mr.dist;
        vec3 normal = getNormal(hitPos, rot);

        // Lambertian diffuse + ambient
        vec3 lightDir = normalize(vec3(0.5, 0.7, -0.8));
        float diffuse = max(dot(normal, lightDir), 0.0);
        float ambient = 0.15;
        intensity = ambient + diffuse * 0.85;
    }

    // ── ASCII character selection ────────────────────────────────────
    int charIndex = int(clamp(intensity * 9.99, 0.0, 9.0));
    int bitmap = ASCII_CHARS[charIndex];
    float pixel = charPixel(bitmap, cellUV);

    // If no hit, pixel stays 0 (transparent)
    float shape = pixel * intensity;

    // ── Border detection on 3D surface ──────────────────────────────
    // Only show border where the ray actually hit the 3D shape.
    // This avoids the half-circle cut planes creating infinite borders.
    float borderBrightness = 0.0;
    if (mr.hit) {
        vec3 hitPos = ro + rd * mr.dist;
        vec3 rp = rot * hitPos;
        float sdf2d = kobaltSDF2D(rp.xy);
        float edgeDist = abs(sdf2d);
        // Also detect Z-face edges (front/back face rims)
        float zEdge = abs(abs(rp.z) - EXTRUDE_DEPTH);
        float minEdge = min(edgeDist, zEdge);
        float borderMask = 1.0 - smoothstep(0.0, BORDER_WIDTH, minEdge);

        // Vertical traveling sweep in logo space (no atan discontinuities)
        float sweep = 0.5 + 0.5 * sin(rp.y * 8.0 - iTime * BORDER_SPEED);
        // Overall pulsation
        float pulsation = 0.7 + 0.3 * sin(iTime * BORDER_PULSE_SPEED);
        borderBrightness = borderMask * sweep * pulsation * BORDER_INTENSITY;
    }

    // ── Dark mask: logo only visible in dark/empty areas ────────────
    float luminance = dot(terminal.rgb, vec3(0.299, 0.587, 0.114));
    float darkMask  = 1.0 - smoothstep(0.05, 0.4, luminance);

    // ── Composite ───────────────────────────────────────────────────
    // ASCII body
    vec3 result = mix(terminal.rgb, LOGO_COLOR, shape * LOGO_OPACITY * darkMask);
    // Border on top (solid yellow, not ASCII-ified)
    result = mix(result, BORDER_COLOR, borderBrightness * LOGO_OPACITY * darkMask);
    fragColor = vec4(result, terminal.a);
}
