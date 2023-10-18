const float TAU = 6.28318530718;
#define BPM 120.0
#define saturate(x) clamp(x, 0., 1.)
#define tri(x) (1. - 4. * abs(fract(x) - .5))
#define phase(x) (floor(x) + .5 + .5 * cos(TAU * .5 * exp(-5. * fract(x))))
void rot(inout vec2 p, float a) { p *= mat2(cos(a), sin(a), -sin(a), cos(a)); }

// Hash without Sine by David Hoskins.
// https://www.shadertoy.com/view/4djSRW
float hash11(float p) {
    p = fract(p * .1031);
    p *= p + 33.33;
    p *= p + p;
    return fract(p);
}

float hash12(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * .1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

vec2 hash22(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * vec3(.1031, .1030, .0973));
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.xx + p3.yz) * p3.zy);
}

vec2 hash23(vec3 p3) {
    p3 = fract(p3 * vec3(.1031, .1030, .0973));
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.xx + p3.yz) * p3.zy);
}

// hemisphere hash function based on a hash by Slerpy
vec3 hashHs(vec3 n, vec3 seed) {
    vec2 h = hash23(seed);
    float a = h.x * 2. - 1.;
    float b = TAU * h.y * 2. - 1.;
    float c = sqrt(1. - a * a);
    vec3 r = vec3(c * cos(b), a, c * sin(b));
    return r;
}

// global vars
vec3 ro, target;
float fov;
vec3 scol;
float beat, beatTau, beatPhase;

// Timeline
float prevEndTime = 0., t = 0.;
#define TL(end) if (t = beat - prevEndTime, beat < (prevEndTime = end))

// Material Types
#define VOL 0.
#define SOL 1.

vec2 opRep(vec2 p, vec2 a) { return mod(p, a) - 0.5 * a; }

void opUnion(inout vec4 m, float d, float type, float roughness_or_emissive, float hue) {
    if (d < m.x) m = vec4(d, type, roughness_or_emissive, hue);
}

vec3 pal(vec4 m) {
    // Integer part: Blend ratio with white (0-10)
    // Decimal part: Hue (0-1)
    vec3 col = vec3(.5) + .5 * cos(TAU * (vec3(0., .33, .67) + m.w));
    return mix(col, vec3(.5), .1 * floor(m.w));
}

float sdBox(vec3 p, vec3 b) {
    vec3 q = abs(p) - b;
    return length(max(q, 0.)) + min(max(q.x, max(q.y, q.z)), 0.);
}

// マンハッタン距離によるボロノイ
// https://qiita.com/7CIT/items/4126d23ffb1b28b80f27
// https://neort.io/art/br0fmis3p9f48fkiuk50
float voronoi(vec2 uv) {
    vec2 i = floor(uv);
    vec2 f = fract(uv);
    vec2 res = vec2(8, 8);

    for (int x = -1; x <= 1; x++) {
        for (int y = -1; y <= 1; y++) {
            vec2 n = vec2(x, y);
            vec2 np = 0.5 + 0.5 * sin((beatPhase / 4. + hash22(i + n)) * TAU);
            vec2 p = n + np - f;

            // マンハッタン距離
            float d = abs(p.x) + abs(p.y);
            // float d = length(p);
            // float d = lpnorm(p, -3);

            if (d < res.x) {
                res.y = res.x;
                res.x = d;
            } else if (d < res.y) {
                res.y = d;
            }
        }
    }

    float c = res.y - res.x;
    c = sqrt(c);
    c = smoothstep(0.4, 0.0, c);
    return c;
}

vec4 map(vec3 pos, bool isFull) {
    vec4 m = vec4(2, VOL, 0, 0);
    // x: Distance
    // y: MaterialType (VOL or SOL)
    // z: Roughness in (0-1), Emissive when z>1
    // w: ColorPalette

    float roughness = 0.05;

    vec3 p1 = pos;

    int _IFS_Iteration = 3;
    vec3 _IFS_Rot = vec3(0, 0.15, -0.25);
    vec3 _IFS_Offset = vec3(3, 4, 12);

    p1 -= _IFS_Offset.xyz;

    for (int i = 0; i < _IFS_Iteration; i++) {
        p1 = abs(p1 + _IFS_Offset.xyz) - _IFS_Offset.xyz;
        rot(p1.xz, TAU * _IFS_Rot.x);
        rot(p1.zy, TAU * _IFS_Rot.y);
        rot(p1.xy, TAU * _IFS_Rot.z);
    }

    float power = (beat >= 32. && beat < 64.) ? 100.0 : 1.0;
    float emi = 1.2 * pow(saturate(cos((beatTau - pos.y * 2.) / 8.)), power);
    float hue = fract(beat / 16.);
    // hue = fract(pos.z / 2.);
    // hue = fract(pos.y / 16.);
    // hue = fract(beat * 0.01);

    vec3 size = vec3(4, 0.1, 4);
    opUnion(m, sdBox(p1, size) + voronoi(p1.xz), SOL, roughness, 0.);
    opUnion(m, sdBox(p1 - vec3(0, -0.2, 0), size), SOL, roughness + emi, hue);

    // wall
    emi = pow(saturate(cos(TAU * p1.x * 0.5)), 50.) * saturate(cos((beatTau - pos.y * 2.) / 8.));
    hue = 3.4;
    opUnion(m, sdBox(p1 - vec3(0, 4, 0), size), SOL, emi * 2., hue);

    return m;
}

vec3 normal(vec3 p) {
    vec2 e = vec2(0, .05);
    return normalize(map(p, false).x - vec3(map(p - e.yxx, false).x, map(p - e.xyx, false).x, map(p - e.xxy, false).x));
}

// Based on EOT - Grid scene by Virgill
// https://www.shadertoy.com/view/Xt3cWS
void madtracer(vec3 ro1, vec3 rd1, float seed) {
    scol = vec3(0);
    vec2 rand = hash23(vec3(seed, iTime, iTime)) * .5;
    float t = rand.x, t2 = rand.y;
    vec4 m1, m2;
    vec3 rd2, ro2, nor2;
    for (int i = 0; i < 100; i++) {
        m1 = map(ro1 + rd1 * t, true);
        // t += m1.y == VOL ? 0.25 * abs(m1.x) + 0.0008 : 0.25 * m1.x;
        t += 0.5 * mix(abs(m1.x) + 0.0032, m1.x, m1.y);
        ro2 = ro1 + rd1 * t;
        nor2 = normal(ro2);
        rd2 = mix(reflect(rd1, nor2), hashHs(nor2, vec3(seed, i, iTime)), saturate(m1.z));
        m2 = map(ro2 + rd2 * t2, true);
        // t2 += m2.y == VOL ? 0.15 * abs(m2.x) : 0.15 * m2.x;
        t2 += 0.25 * mix(abs(m2.x), m2.x, m2.y);
        scol += .15 * (pal(m2) * max(0., m2.z - 1.) + pal(m1) * max(0., m1.z - 1.));

        // force disable unroll for WebGL 1.0
        if (t < -1.) break;
    }
}

void raymarching(vec3 ro1, vec3 rd1) {
    scol = vec3(0);
    float t = 0.;
    vec4 m;
    for (int i = 0; i < 160; i++) {
        vec3 p = ro1 + rd1 * t;
        m = map(p, true);
        t += m.x;

        if (m.x < 0.01) {
            vec3 light = normalize(vec3(1, 1, -1));
            vec3 albedo = vec3(0.3);
            if (m.z > 1.) albedo = pal(m);
            scol = albedo * (0.5 + 0.5 * saturate(dot(normal(p), light)));
            break;
        }
    }
}

void mainImage(out vec4 fragColor, vec2 fragCoord) {
    beat = iTime * BPM / 60.0;
    // beat = 16.;
    beat = mod(beat, 96.0);
    beatTau = beat * TAU;
    beatPhase = phase(beat / 2.);

    vec2 uv = fragCoord.xy / iResolution.xy;

    // Camera
    vec2 noise = hash23(vec3(iTime, fragCoord)) - .5;  // AA
    vec2 uv2 = (2. * (fragCoord.xy + noise) - iResolution.xy) / iResolution.x;

    // Timeline
    TL(16.) {
        vec3 a = vec3(0, 0.1, 0.01) * t;
        ro = vec3(3.685370226301841, -4.959968195098165, -20.681291773889914) + a;
        target = vec3(0, 0, 0) + a;
        fov = 38.;
    }
    else TL(32.) {
        vec3 a = vec3(0, 0., 0.01) * t;
        ro = vec3(0., 11.945982556636304, 38.08763743207477) + a;
        target = vec3(0, 0, 0) + a;
        fov = 38.;
    }
    else TL(64.) {
        vec3 a = vec3(0, 0., 0.2) * t;
        ro = vec3(0, 9.715572757794958e-16, 15.866734416093387) + a;
        target = vec3(0, 0, 0) + a;
        fov = 38. + t;
    }
    else TL(80.) {
        vec3 a = vec3(0, 0.1, 0.01) * t;
        ro = vec3(-1.3462260362305196, -8.261048814107882, -28.966739530232058) + a;
        target = vec3(1.593920748030086, -0.030320796976565673, -0.9344052773004179) + a;
        fov = 38.;
    }
    else TL(96.) {
        vec3 a = vec3(0, -1.0, 0.01) * t;
        ro = vec3(0., -63.37835217641502, -0.414008392856417) + a;
        target = vec3(0, 0, 0) + a;
        fov = 38.;
    }

#define DEBUG_CAMERA
#ifdef DEBUG_CAMERA
    if (gCameraDebug > 0.) {
        ro = vec3(gCameraEyeX, gCameraEyeY, gCameraEyeZ);
        target = vec3(gCameraTargetX, gCameraTargetY, gCameraTargetZ);
        fov = gCameraFov;
    }
#endif

    vec3 up = vec3(0, 1, 0);
    vec3 fwd = normalize(target - ro);
    vec3 right = normalize(cross(up, fwd));
    up = normalize(cross(fwd, right));
    vec3 rd = normalize(right * uv2.x + up * uv2.y + fwd / tan(fov * TAU / 720.));

// #define DEBUG_SCENE
#ifdef DEBUG_SCENE
    raymarching(ro, rd);
    fragColor = vec4(scol, 1.);
#else
    madtracer(ro, rd, hash12(uv2));
    vec3 bufa = texture(iChannel0, uv).xyz;

    // fade out
    // scol = mix(scol, vec3(0), smoothstep(92., 96., beat));
    fragColor = saturate(vec4(0.7 * scol + 0.7 * bufa, 1.));
#endif
}