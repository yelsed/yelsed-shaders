// Omarchy Logo 3D ASCII Art Shader
// Renders the Omarchy icon as a 3D extruded model displayed with ASCII characters,
// with a "spin-in" deceleration on tab open.
// Logo geometry derived from ~/.config/omarchy/branding/about.txt (54×26 block-char grid).
// Place BEFORE tft.glsl in Ghostty config.

// ── User-configurable constants ─────────────────────────────────────────
const float LOGO_SCALE      = 0.30;    // size relative to screen height
const float LOGO_OPACITY    = 0.35;    // base opacity
const float ROTATION_SPEED  = -0.4;    // radians per second (negative = reverse)
const float EXTRUDE_DEPTH   = 0.15;    // Z extrusion half-depth
const vec3  LOGO_COLOR      = vec3(0.133, 0.773, 0.369); // #22c55e Omarchy green
const float CELL_SIZE       = 8.0;     // pixel size of each ASCII cell
const bool  OSCILLATE       = false;   // true = rock back and forth, false = continuous spin
const float OSCILLATE_RANGE = 0.8;     // max angle in radians when oscillating
const float ROUND_RADIUS    = 0.02;    // rounding to soften edges

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

float sdBox(vec2 p, vec2 b) {
    vec2 d = abs(p) - b;
    return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

// Omarchy icon 2D SDF — derived from about.txt (54×26 block-char grid)
// SDF space: x∈[-2,2], y∈[-0.5,0.5]
// Each logical pixel is 1 col wide × 2 text-rows tall.
float omarchySDF2D(vec2 p) {
    const float CW = 1.0 / 54.0;  // col unit width in SDF space (1/54 preserves terminal 2:1 char aspect)
    const float RH = 1.0 / 26.0;  // text-row unit height in SDF space

    // Box over inclusive col range [c0,c1] and text-row range [r0,r1]
    #define R(c0,c1,r0,r1) sdBox(p - vec2((float(c0+c1+1)*0.5*CW - 0.5), (0.5 - float(r0+r1+1)*0.5*RH)), vec2(float(c1-c0+1)*0.5*CW, float(r1-r0+1)*0.5*RH))

    float d = R( 0, 53,  0,  1);   // top full bar
    d = min(d, R( 0,  3,  2, 23)); // left outer column
    d = min(d, R(50, 53,  2, 23)); // right outer column
    d = min(d, R(25, 28,  2,  3)); // middle-top pillar
    d = min(d, R(25, 28, 22, 23)); // middle-bottom pillar
    d = min(d, R( 8, 28,  4,  5)); // top H-bar, left section
    d = min(d, R(38, 45,  4,  5)); // top H-bar, right section
    d = min(d, R( 8, 11,  4, 21)); // inner-left column
    d = min(d, R(42, 45,  4, 21)); // inner-right column
    d = min(d, R( 0, 11, 12, 13)); // extended left at midpoint
    d = min(d, R( 8, 45, 20, 21)); // bottom H-bar
    d = min(d, R( 0, 28, 24, 25)); // bottom-left partial bar
    d = min(d, R(34, 53, 24, 25)); // bottom-right partial bar

    #undef R
    return d;
}

// Extrude 2D SDF into 3D along Z
float omarchySDF3D(vec3 p) {
    float d2d = omarchySDF2D(p.xy);
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
        float d = omarchySDF3D(rp);
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
    float d = omarchySDF3D(rp);
    return normalize(vec3(
        omarchySDF3D(rot * (p + vec3(e,0,0))) - d,
        omarchySDF3D(rot * (p + vec3(0,e,0))) - d,
        omarchySDF3D(rot * (p + vec3(0,0,e))) - d
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

    // ── Dark mask: logo only visible in dark/empty areas ────────────
    float luminance = dot(terminal.rgb, vec3(0.299, 0.587, 0.114));
    float darkMask  = 1.0 - smoothstep(0.05, 0.4, luminance);

    // ── Composite ───────────────────────────────────────────────────
    vec3 result = mix(terminal.rgb, LOGO_COLOR, shape * LOGO_OPACITY * darkMask);
    fragColor = vec4(result, terminal.a);
}
