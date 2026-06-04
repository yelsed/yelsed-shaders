// Fivespark Star 3D ASCII Art Shader — Glowing Border Edition
// Renders the Fivespark star icon as a 3D extruded model displayed with ASCII characters,
// with an animated white border and a "spin-in" deceleration on tab open.
// Place BEFORE tft.glsl in Ghostty config.
//
// SVG source: fivespark-star.svg — to use a different logo, update fiveSparkSDF2D().
// The star has two sub-paths: a 12-vertex main body and a 4-vertex lower-right ray.

// ── User-configurable constants ─────────────────────────────────────────
const float LOGO_SCALE      = 0.30;    // size relative to screen height
const float LOGO_OPACITY    = 0.35;    // base opacity
const float ROTATION_SPEED  = -0.4;   // radians per second (negative = reverse)
const float EXTRUDE_DEPTH   = 0.15;   // Z extrusion half-depth
const vec3  LOGO_COLOR      = vec3(1.0, 0.761, 0.0); // #FFC200
const float CELL_SIZE       = 8.0;    // pixel size of each ASCII cell
const bool  OSCILLATE       = false;  // true = rock back and forth, false = continuous spin
const float OSCILLATE_RANGE = 0.8;    // max angle in radians when oscillating
const float ROUND_RADIUS    = 0.01;   // rounding to soften edges

// ── Border constants ────────────────────────────────────────────────────
const vec3  BORDER_COLOR       = vec3(1.0, 1.0, 1.0);
const float BORDER_WIDTH       = 0.02;
const float BORDER_SPEED       = 2.0;
const float BORDER_PULSE_SPEED = 1.5;
const float BORDER_INTENSITY   = 1.0;

// ── Spin-in constants ───────────────────────────────────────────────────
const float SPIN_DECEL_RATE = 0.7;
const float SPIN_BOOST      = 14.0;

// ── ASCII character set ─────────────────────────────────────────────────
// 10 density levels: " .:-=+*#%@"
// Each character is a 4x6 bitmap packed into 24 bits (stored as int).

int ASCII_CHARS[10] = int[10](
    0x000000,
    0x000600,
    0x006006,
    0x000F00,
    0x0F00F0,
    0x046E46,
    0x069F96,
    0x69F69F,
    0x936C93,
    0x6F9F9F
);

float charPixel(int bitmap, vec2 cellUV) {
    int col = int(cellUV.x * 4.0);
    int row = int(cellUV.y * 6.0);
    col = clamp(col, 0, 3);
    row = clamp(row, 0, 5);
    int bitIndex = row * 4 + col;
    return float((bitmap >> bitIndex) & 1);
}

// ── Fivespark star SDF (from fivespark-star.svg) ────────────────────────
// Coordinates normalized from SVG viewBox "0 0 23 22":
//   center = (11.5, 11), scale = 1/23, Y flipped for GLSL (+y up).
// Two polygon SDFs unioned: main body (12 verts) + lower-right ray (4 verts).

float fiveSparkSDF2D(vec2 p) {
    // Main star body (path 1)
    vec2 v0[12] = vec2[12](
        vec2( 0.4998,  0.0680),  // right outer point
        vec2( 0.4599,  0.1909),  // upper right
        vec2( 0.0645,  0.0625),  // right wall of top notch base
        vec2( 0.0645,  0.4783),  // top right of notch
        vec2(-0.0646,  0.4783),  // top left of notch
        vec2(-0.0646,  0.0625),  // left wall of top notch base
        vec2(-0.4602,  0.1909),  // upper left
        vec2(-0.5000,  0.0680),  // left outer point
        vec2(-0.1045, -0.0604),  // inner left junction
        vec2(-0.3490, -0.3968),  // lower-left outer
        vec2(-0.2444, -0.4731),  // lower-left tip
        vec2( 0.0396, -0.0817)   // inner bottom junction
    );
    float d0 = dot(p - v0[0], p - v0[0]);
    float s0 = 1.0;
    int j0 = 11;
    for (int i = 0; i < 12; i++) {
        vec2 e = v0[j0] - v0[i];
        vec2 w = p - v0[i];
        vec2 b = w - e * clamp(dot(w, e) / dot(e, e), 0.0, 1.0);
        d0 = min(d0, dot(b, b));
        bvec3 c = bvec3(p.y >= v0[i].y, p.y < v0[j0].y, e.x * w.y > e.y * w.x);
        if (all(c) || all(not(c))) s0 *= -1.0;
        j0 = i;
    }

    // Lower-right ray (path 2)
    vec2 v1[4] = vec2[4](
        vec2( 0.1590, -0.1353),  // inner right junction
        vec2( 0.0545, -0.2113),  // inner left of ray
        vec2( 0.2443, -0.4725),  // lower-right tip
        vec2( 0.3488, -0.3967)   // outer right of ray
    );
    float d1 = dot(p - v1[0], p - v1[0]);
    float s1 = 1.0;
    int j1 = 3;
    for (int i = 0; i < 4; i++) {
        vec2 e = v1[j1] - v1[i];
        vec2 w = p - v1[i];
        vec2 b = w - e * clamp(dot(w, e) / dot(e, e), 0.0, 1.0);
        d1 = min(d1, dot(b, b));
        bvec3 c = bvec3(p.y >= v1[i].y, p.y < v1[j1].y, e.x * w.y > e.y * w.x);
        if (all(c) || all(not(c))) s1 *= -1.0;
        j1 = i;
    }

    return min(s0 * sqrt(d0), s1 * sqrt(d1));
}

float fiveSparkSDF3D(vec3 p) {
    float d2d = fiveSparkSDF2D(p.xy);
    float dz  = abs(p.z) - EXTRUDE_DEPTH;
    float d = min(max(d2d, dz), length(max(vec2(d2d, dz), 0.0)));
    return d - ROUND_RADIUS;
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
        vec3 rp = rot * p;
        float d = fiveSparkSDF3D(rp);
        if (d < SURF_DIST) return MarchResult(t, true);
        t += d;
        if (t > MAX_DIST) break;
    }
    return MarchResult(t, false);
}

vec3 getNormal(vec3 p, mat3 rot) {
    const float e = 0.001;
    vec3 rp = rot * p;
    float d = fiveSparkSDF3D(rp);
    return normalize(vec3(
        fiveSparkSDF3D(rot * (p + vec3(e, 0, 0))) - d,
        fiveSparkSDF3D(rot * (p + vec3(0, e, 0))) - d,
        fiveSparkSDF3D(rot * (p + vec3(0, 0, e))) - d
    ));
}

// ── Main ────────────────────────────────────────────────────────────────

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec4 terminal = texture(iChannel0, uv);

    vec2 cellIndex  = floor(fragCoord / CELL_SIZE);
    vec2 cellCenter = (cellIndex + 0.5) * CELL_SIZE;
    vec2 cellUV     = fract(fragCoord / CELL_SIZE);

    float aspect = iResolution.x / iResolution.y;
    vec2 ndc = (cellCenter / iResolution.xy - 0.5) * vec2(aspect, -1.0);
    vec2 p2d = ndc / LOGO_SCALE;

    vec3 ro = vec3(p2d, -2.0);
    vec3 rd = vec3(0.0, 0.0, 1.0);

    // Integrated angle with spin-in deceleration
    float t = iTime;
    float angle;
    if (OSCILLATE) {
        angle = sin(t * ROTATION_SPEED) * OSCILLATE_RANGE;
    } else {
        angle = ROTATION_SPEED * (t + SPIN_BOOST / SPIN_DECEL_RATE * (1.0 - exp(-t * SPIN_DECEL_RATE)));
    }
    mat3 rot = rotateY(angle);

    MarchResult mr = rayMarch(ro, rd, rot);

    float intensity = 0.0;
    if (mr.hit) {
        vec3 hitPos = ro + rd * mr.dist;
        vec3 normal = getNormal(hitPos, rot);
        vec3 lightDir = normalize(vec3(0.5, 0.7, -0.8));
        float diffuse = max(dot(normal, lightDir), 0.0);
        intensity = 0.15 + diffuse * 0.85;
    }

    int charIndex = int(clamp(intensity * 9.99, 0.0, 9.0));
    int bitmap = ASCII_CHARS[charIndex];
    float pixel = charPixel(bitmap, cellUV);
    float shape = pixel * intensity;

    float borderBrightness = 0.0;
    if (mr.hit) {
        vec3 hitPos = ro + rd * mr.dist;
        vec3 rp = rot * hitPos;
        float sdf2d   = fiveSparkSDF2D(rp.xy);
        float edgeDist = abs(sdf2d);
        float zEdge   = abs(abs(rp.z) - EXTRUDE_DEPTH);
        float minEdge = min(edgeDist, zEdge);
        float borderMask  = 1.0 - smoothstep(BORDER_WIDTH - 0.005, BORDER_WIDTH, minEdge);
        float sweep       = 0.65 + 0.35 * sin(rp.y * 8.0 - iTime * BORDER_SPEED);
        float pulsation   = 0.85 + 0.15 * sin(iTime * BORDER_PULSE_SPEED);
        borderBrightness  = borderMask * sweep * pulsation * BORDER_INTENSITY;
    }

    float luminance = dot(terminal.rgb, vec3(0.299, 0.587, 0.114));
    float darkMask  = 1.0 - smoothstep(0.05, 0.4, luminance);

    vec3 result = mix(terminal.rgb, LOGO_COLOR, shape * LOGO_OPACITY * darkMask);
    result = mix(result, BORDER_COLOR, borderBrightness * LOGO_OPACITY * darkMask);
    fragColor = vec4(result, terminal.a);
}
