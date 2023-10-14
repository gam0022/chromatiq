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
vec3 boxPos;

// Timeline
float prevEndTime = 0., t = 0.;
#define TL(end) if (t = beat - prevEndTime, beat < (prevEndTime = end))

// Material Types
#define VOL 0.
#define SOL 1.

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

float sdBox(vec2 p, vec2 b) {
    vec2 q = abs(p) - b;
    return length(max(q, 0.)) + min(max(q.x, q.y), 0.);
}

// Hexagons - distance by iq
// https://www.shadertoy.com/view/Xd2GR3
// return: { 2d cell id (vec2), distance to border, distnace to center }
#define INV_SQRT3 0.5773503
vec4 hexagon(inout vec2 p) {
    vec2 q = vec2(p.x * 2. * INV_SQRT3, p.y + p.x * INV_SQRT3);

    vec2 pi = floor(q);
    vec2 pf = fract(q);

    float v = mod(pi.x + pi.y, 3.);

    float ca = step(1., v);
    float cb = step(2., v);
    vec2 ma = step(pf.xy, pf.yx);

    // distance to borders
    float e = dot(ma, 1. - pf.yx + ca * (pf.x + pf.y - 1.) + cb * (pf.yx - 2. * pf.xy));

    // distance to center
    p = vec2(q.x + floor(.5 + p.y / 1.5), 4. * p.y / 3.) * .5 + .5;
    p = (fract(p) - .5) * vec2(1., .85);
    float f = length(p);

    return vec4(pi + ca - cb * ma, e, f);
}

float warning(vec2 p) {
    vec4 h = hexagon(p);

    float f = fract(hash12(h.xy) + beatPhase);
    f = mix(f, saturate(sin(h.x - h.y + 4. * beatPhase)), .5 + .5 * sin(beatTau / 16.));
    float hex = smoothstep(.1, .11, h.z) * f;

    float mark = 1.;
    float dice = fract(hash12(h.xy) + beatPhase / 4.);

    if (dice < .25) {
        float d = sdBox(p, vec2(.4, dice));
        float ph = phase(beat / 2. + f);
        float ss = smoothstep(1., 1.05, mod(p.x * 10. + 10. * p.y + 8. * ph, 2.));
        mark = saturate(step(0., d) + ss);
    } else {
        vec4[] param_array = vec4[](vec4(140., 72., 0., 0.), vec4(0., 184., 482, 0.), vec4(0., 0., 753., 0.), vec4(541., 156., 453., 0.), vec4(112., 0., 301., 0.),  // 0-3
                                    vec4(311., 172., 50., 0.), vec4(249., 40., 492., 0.), vec4(0.), vec4(1.));                                                       // 4-7

        vec4 param = param_array[int(mod(dice * 33.01, 8.))] / vec2(1200., 675.).xyxy;
        // param = PU;
        vec2 p1 = p - param.xy;
        for (int i = 0; i < 3; i++) {
            p1 = abs(p1 + param.xy) - param.xy;
            rot(p1, TAU * param.z);
        }

        float d = sdBox(p1, vec2(.2, .05));
        mark = saturate(smoothstep(0., .01, d));
    }

    return saturate(hex * mark);
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
            vec2 np = 0.5 + 0.5 * sin(beatPhase + hash22(i + n));
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
    float a = .1;
    float W = 16.;
    float H = 8.;
    float D = 16.;

    vec3 p1 = pos - boxPos;

    float boxEmi;

    boxEmi = 1.8 * abs(cos((beatTau - p1.y * 2.) / 8.));
    vec4 _IFS_BoxBase = vec4(1, 1, 1, 0) * 2.;

    float hue = 0.5;
    float emi = 0.;

    vec4 mp = m;
    opUnion(m, max(sdBox(p1, _IFS_BoxBase.xyz) + voronoi((pos.zy)), sdBox(p1, _IFS_BoxBase.xyz - vec3(0.05))), SOL, roughness, hue);
    opUnion(m, sdBox(p1, _IFS_BoxBase.xyz - vec3(0.2)), SOL, roughness + boxEmi, hue);

    // room
    vec3 p2 = abs(pos);

    // floor and ceil
    opUnion(m, sdBox(p2 - vec3(0, H + 4., 0), vec3(W, 4., D)), SOL, roughness, 10.);

    // door
    emi = step(p2.x, 2.) * step(p2.y, 2.);
    // if (mod(beat, 2.) < 1. && (beat < 48. || beat > 300.)) emi = 1. - emi;
    opUnion(m, sdBox(p2 - vec3(0, 0, D + a), vec3(W, H, a)), SOL, roughness + emi * 2., 10.0);

    // wall
    if (isFull) {
        float id = floor((pos.z + D) / 4.);
        emi = step(1., mod(id, 2.));
        hue = 10.;
    }

    opUnion(m, sdBox(p2 - vec3(W + a, 0, 0), vec3(a, H, D)), SOL, roughness + emi * 2., hue);

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
    for (int i = 0; i < 130; i++) {
        m1 = map(ro1 + rd1 * t, true);
        // t += m1.y == VOL ? 0.25 * abs(m1.x) + 0.0008 : 0.25 * m1.x;
        t += 0.25 * mix(abs(m1.x) + 0.0032, m1.x, m1.y);
        ro2 = ro1 + rd1 * t;
        nor2 = normal(ro2);
        rd2 = mix(reflect(rd1, nor2), hashHs(nor2, vec3(seed, i, iTime)), saturate(m1.z));
        m2 = map(ro2 + rd2 * t2, true);
        // t2 += m2.y == VOL ? 0.15 * abs(m2.x) : 0.15 * m2.x;
        t2 += 0.15 * mix(abs(m2.x), m2.x, m2.y);
        scol += .015 * (pal(m2) * max(0., m2.z - 1.) + pal(m1) * max(0., m1.z - 1.));

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
    beatTau = beat * TAU;
    beatPhase = phase(beat / 2.);

    vec2 uv = fragCoord.xy / iResolution.xy;

    boxPos = vec3(0, -6, 0);
    // boxPos.y = mix(-12., 0., smoothstep(20., 48., beat));
    // boxPos.y = mix(boxPos.y, -12., smoothstep(304., 320., beat));

    // Camera
    vec2 noise = hash23(vec3(iTime, fragCoord)) - .5;  // AA
    vec2 uv2 = (2. * (fragCoord.xy + noise) - iResolution.xy) / iResolution.x;

    // 通常時カメラ
    float dice = hash11(floor(beat / 8. + 2.) * 123.);
    if (dice < .8)
        ro = vec3(8. * cos(beatTau / 128.), mix(-6., 6., dice), 8. * sin(beatTau / 128.));
    else
        ro = vec3(9.5 - dice * 20., 1., -12.3);

    target = boxPos;
    // target = vec3(0, -2, 0);
    fov = 90.;

    // ro = vec3(1.0 * cos(beatTau / 128.), -4., 1.0 * sin(beatTau / 128.));
    ro = vec3(4, -6., 1.);
    ro = vec3(7. * cos(beatTau / 128.), -6., 7. * sin(beatTau / 128.));

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
    scol = mix(scol, vec3(0), smoothstep(316., 320., beat));
    fragColor = saturate(vec4(0.7 * scol + 0.7 * bufa, 1.));
#endif
}