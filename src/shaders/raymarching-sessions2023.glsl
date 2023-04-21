
uniform float gCameraEyeX;     // -0.08828528243935951 -100 100 camera
uniform float gCameraEyeY;     // 3.5309297601209235 -100 100
uniform float gCameraEyeZ;     // -2.705631420983895 -100 100
uniform float gCameraTargetX;  // 0.7576763789243015 -100 100
uniform float gCameraTargetY;  // 3.4515422110479044 -100 100
uniform float gCameraTargetZ;  // -0.21633410393024527 -100 100
uniform float gCameraFov;      // 37.88049605411499 0 180
uniform float gCameraDebug;    // 0 0 1

#define opRep(p, a) p = mod(p, a) - a * .5
#define opRepLim(p, c, l) p = p - c * clamp(floor(p / c + .5), -l, l);

#define tri(x) (1. - 4. * abs(fract(x) - .5))
#define phase(x) (floor(x) + .5 + .5 * cos(TAU * .5 * exp(-5. * fract(x))))
void rot(inout vec2 p, float a) { p *= mat2(cos(a), sin(a), -sin(a), cos(a)); }

vec3 ro, target;
float fov;
vec3 scol;
float beat, beatTau, beatPhase;
vec3 boxPos;

// Timeline
float prevEndTime = 0., t = 0.;
#define TL(end) if (t = beat - prevEndTime, beat < (prevEndTime = end))

// https://www.shadertoy.com/view/3tX3R4
float remap(float val, float im, float ix, float om, float ox) { return clamp(om + (val - im) * (ox - om) / (ix - im), om, ox); }
float remap01(float val, float im, float ix) { return saturate((val - im) / (ix - im)); }

// Material Types
#define VOL 0.0
#define SOL 1.0

void opUnion(inout vec4 m, float d, float type, float roughness_or_emissive, float hue) {
    if (d < m.x) m = vec4(d, type, roughness_or_emissive, hue);
}

vec3 pal(vec4 m) {
    // Integer part: Blend ratio with white (0-10)
    // Decimal part: Hue (0-1)
    vec3 col = vec3(0.5) + 0.5 * cos(TAU * (vec3(0.0, 0.33, 0.67) + m.w));
    return mix(col, vec3(.5), 0.1 * floor(m.w));
}

float sdBox(vec3 p, vec3 b) {
    vec3 q = abs(p) - b;
    return length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0);
}

float sdBox(vec2 p, vec2 b) {
    vec2 d = abs(p) - b;
    return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

// https://www.shadertoy.com/view/Xd2GR3
// { 2d cell id, distance to border, distnace to center )
#define INV_SQRT3 0.5773503
vec4 hexagon(inout vec2 p) {
    vec2 q = vec2(p.x * 2.0 * INV_SQRT3, p.y + p.x * INV_SQRT3);

    vec2 pi = floor(q);
    vec2 pf = fract(q);

    float v = mod(pi.x + pi.y, 3.0);

    float ca = step(1.0, v);
    float cb = step(2.0, v);
    vec2 ma = step(pf.xy, pf.yx);

    // distance to borders
    float e = dot(ma, 1.0 - pf.yx + ca * (pf.x + pf.y - 1.0) + cb * (pf.yx - 2.0 * pf.xy));

    // distance to center
    p = vec2(q.x + floor(0.5 + p.y / 1.5), 4.0 * p.y / 3.0) * 0.5 + 0.5;
    p = (fract(p) - 0.5) * vec2(1.0, 0.85);
    float f = length(p);

    return vec4(pi + ca - cb * ma, e, f);
}

float warning(vec2 p) {
    vec4 h = hexagon(p);

    float f = fract(hash12(h.xy) + beatPhase);
    f = mix(f, saturate(sin(h.x - h.y + 4. * beatPhase)), .5 + .5 * sin(beatTau / 16.));
    float hex = smoothstep(0.10, 0.11, h.z) * f;

    float mark = 1.;
    float dice = fract(hash12(h.xy) + beatPhase / 4.);

    if (dice < .25) {
        float d = sdBox(p, vec2(0.4, dice));
        float ph = phase(beat / 2. + f);
        float ss = smoothstep(1.0, 1.05, mod(p.x * 10. + 10. * p.y + 8. * ph, 2.));
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

        float d = sdBox(p1, vec2(0.2, 0.05));
        mark = saturate(smoothstep(0., 0.01, d));
    }

    return saturate(hex * mark);
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
    float D = 30.;

    vec3 p1 = pos;

    float boxEmi;

    if (mod(beat, 8.) > 4.) {
        boxEmi = 2.2 * saturate(sin(beatTau * 4.));
    } else {
        boxEmi = 2.2 * abs(cos((beatTau - p1.y) / 4.));
    }

    vec4 _IFS_Rot = vec4(0.34 + beatPhase / 2.3, -0.28, 1.03, 0.);
    vec4 _IFS_Offset = vec4(1.36, 0.06, 0.69, 1.);
    float _IFS_Iteration = phase(tri(beat / 16.) + 2.);
    vec4 _IFS_BoxBase = vec4(1, 1, 1, 0);
    vec4 _IFS_BoxEmissive = vec4(0.05, 1.05, 1.05, 0);
    float hue = 0.5;
    bool emi2 = false;

    TL(40.) {
        _IFS_Rot *= 0.;
        _IFS_Offset *= 0.;
        _IFS_Iteration = 1.;
    }
    else TL(48.) {
        float fade = saturate(phase((beat - 48.) / 4.));
        _IFS_Iteration = 1. + fade;
        _IFS_Offset = vec4(1.36, 0.06, 0.69, 1.) * fade;
    }
    else TL(84.) {
    }
    else TL(96.) {
        emi2 = true;
    }
    else TL(128.) {
        emi2 = true;
        hue = fract(0.12 * beatPhase);
    }
    else TL(160.) {
        emi2 = true;
        hue = fract(beatPhase * .1 + pos.z) + 1.;
        boxEmi *= 1.7;
    }
    else TL(200.) {
        emi2 = false;
        hue = fract(.12 * beatPhase);
    }
    else TL(250.) {
        emi2 = true;
        hue = fract(.12 * beatPhase);
    }
    else TL(264.) {
        hue = 0.;
    }
    else TL(288.) {
        emi2 = true;
        hue = 0.;
        _IFS_Iteration = 3. + phase(min(t / 4., 2.));
        _IFS_Rot = vec4(0.3 + 0.1 * sin(beatPhase * TAU / 8.), 0.9 + 0.1 * sin(beatPhase * TAU / 8.), 0.4, 0.);
        _IFS_Offset = vec4(1.4, 0.66, 1.2, 1.);
        boxEmi *= .7;
    }
    else TL(304.) {
        emi2 = (beat < 296.);
        _IFS_Iteration = 4. - phase(min(t / 8., 2.));
    }
    else TL(320.) {
        float a = phase(saturate(t / 8.));
        _IFS_Iteration = 2. - a;
        _IFS_Rot *= (1. - a);
        _IFS_Offset *= (1. - a);
    }

    p1 -= (boxPos + _IFS_Offset.xyz);

    vec3 pp1 = p1;

    for (int i = 0; i < int(_IFS_Iteration); i++) {
        pp1 = p1 + _IFS_Offset.xyz;
        p1 = abs(p1 + _IFS_Offset.xyz) - _IFS_Offset.xyz;
        rot(p1.xz, TAU * _IFS_Rot.x);
        rot(p1.zy, TAU * _IFS_Rot.y);
        rot(p1.xy, TAU * _IFS_Rot.z);
    }

    vec4 mp = m;
    opUnion(m, sdBox(p1, _IFS_BoxBase.xyz), SOL, roughness, 0.5);
    opUnion(m, sdBox(p1, _IFS_BoxEmissive.xyz), SOL, roughness + boxEmi, hue);
    if (emi2) opUnion(m, sdBox(p1, _IFS_BoxEmissive.yzx), SOL, roughness + boxEmi, hue + 0.5);
    opUnion(mp, sdBox(pp1, _IFS_BoxBase.xyz), SOL, roughness, 0.5);
    opUnion(mp, sdBox(pp1, _IFS_BoxEmissive.xyz), SOL, roughness + boxEmi, hue);
    if (emi2) opUnion(mp, sdBox(pp1, _IFS_BoxEmissive.yzx), SOL, roughness + boxEmi, hue + 0.5);

    m = mix(mp, m, fract(_IFS_Iteration));

    // room
    vec3 p2 = abs(pos);
    float hole = sdBox(pos - vec3(0., -H - 0.5, 0.), vec3(1.1) * smoothstep(18., 24., beat));

    // floor and ceil
    opUnion(m, max(sdBox(p2 - vec3(0, H + 4., 0), vec3(W, 4., D)), -hole), SOL, roughness, 10.);

    // door
    float emi = step(p2.x, 2.) * step(p2.y, 2.);
    if (mod(beat, 2.) < 1. && (beat < 48. || beat > 300.)) emi = 1. - emi;
    opUnion(m, sdBox(p2 - vec3(0, 0, D + a), vec3(W, H, a)), SOL, roughness + emi * 2., 10.0);

    // wall
    if (isFull) {
        float id = floor((pos.z + D) / 4.);
        hue = 10.;

        TL(18.) { emi = step(1., mod(id, 2.)) * step(id, mod(beat * 4., 16.)); }
        else TL(32.) {
            emi = step(1., mod(id, 2.));
        }
        else TL(126.0) {
            emi = step(1., mod(id, 2.)) * step(id, mod(beat * 4., 16.));
            emi = mix(emi, step(.5, hash12(floor(pos.yz) + 123.23 * floor(beat * 2.))), saturate(beat - 110. - pos.y));
        }
        else TL(152.) {
            emi = step(.5, hash12(floor(pos.yz) + 123.23 * floor(beat * 2.)));
        }
        else TL(170.) {
            emi = pow(hash12(floor(pos.yz) + 123.23 * floor(beat * 2.)), 4.);
            hue = 3.65;
        }
        else TL(200.) {
            emi = pow(hash12(floor(pos.yz * mix(1., 16., smoothstep(198., 200., beat))) + 123.23 * floor(beat * 2.)), 4.);
            emi = mix(emi, step(.0, emi) * step(3., mod(floor((pos.z + D) / 2.), 4.)), smoothstep(198., 200., beat));

            hue = hash12(floor(pos.yz) + 123.23 * floor(beat * 8.));
            hue = mix(hue, 10., smoothstep(196., 200., beat));
        }
        else TL(250.) {
            emi = step(3., mod(floor((pos.z + D) / 2.), 4.)) * step(1., mod(floor(pos.y - pos.z - 4. * beatPhase), 2.));
        }
        else TL(297.) {
            hue = 0.;
            float fade1 = smoothstep(250., 256., beat);
            float fade2 = smoothstep(292., 297., beat);
            float pw = mix(10., 0.6, fade1);
            pw = mix(pw, 0.7, fade2);
            emi = pow(warning(pos.zy / 2.), pw) * mix(1., step(0., sin(t * 15. * TAU)), fade1 * fade2);
            emi = step(0.5, emi) * emi * 1.05;
        }
        else TL(320.) {
            emi = step(1., mod(id, 2.)) * step(id, mod(beat * 4., 16.));
        }
    }

    opUnion(m, sdBox(p2 - vec3(W + a, 0, 0), vec3(a, H, D)), SOL, roughness + emi * 2., hue);

    return m;
}

vec3 normal(vec3 p) {
    vec2 e = vec2(0, .05);
    return normalize(map(p, false).x - vec3(map(p - e.yxx, false).x, map(p - e.xyx, false).x, map(p - e.xxy, false).x));
}

// Ref. EOT - Grid scene by Virgill
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
        // t2 += m2.y == VOL ? 0.25 * abs(m2.x) : 0.25 * m2.x;
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

    boxPos = vec3(0);
    boxPos.y = mix(-12., 0., smoothstep(20., 48., beat));
    boxPos.y = mix(boxPos.y, -12., smoothstep(304., 320., beat));

    // Camera
    vec2 noise = hash23(vec3(iTime, fragCoord)) - 0.5;  // AA
    vec2 uv2 = (2. * (fragCoord.xy + noise) - iResolution.xy) / iResolution.x;

    // 通常時カメラ
    float dice = hash11(floor(beat / 8. + 2.) * 123.);
    if (dice < 0.8)
        ro = vec3(8. * cos(beatTau / 128.), mix(-6., 6., dice), 8. * sin(beatTau / 128.));
    else
        ro = vec3(9.5 - dice * 20., 1., -12.3);

    target = boxPos;
    fov = 120.;

    // Timeline
    TL(8.) {
        ro = vec3(0, -1.36, -12.3 + t * .3);
        target = vec3(0.0, -2.2, 0.0);
        fov = 100.;
    }
    else TL(16.) {
        ro = vec3(9.5, -1.36, -12.3 + t * .3);
        target = vec3(0.0, -2.2, 0.0);
        fov = 100.;
    }
    else TL(20.) {
        ro = vec3(5.5, -5, -1.2);
        target = vec3(0., -8., -0.);
        fov = 100.0 + t;
    }
    else TL(32.) {
        ro = vec3(5.5, -5, -1.2);
        target = vec3(0., -8., -0.);
        fov = 60.0 + t;
    }
    else TL(38.) {
        ro = vec3(10.8, -4.2, -7.2 + t * .1);
        fov = 93.;
    }
    else TL(44.) {
        ro = vec3(0., 1., -12.3);
        target = vec3(0);
        fov = 100. - t;
    }
    else TL(60.) {
        ro = vec3(0., 1., -12.3);
        fov = 70. - t;
    }
    else TL(70.) {
        ro = vec3(8. * cos(beatTau / 128.), 1., 8. * sin(beatTau / 128.));
        fov = 70.;
    }
    else TL(104.) {
    }
    else TL(112.) {
        ro = vec3(-5., 1.0, 18.0);
        target = vec3(5.0, -1.0, 16.0);
        fov = 100. - t;
    }
    else TL(124.) {
    }
    else TL(130.) {
        ro = vec3(0., 1., -12.3);
        fov = 70. - t;
    }
    else TL(196.) {
    }
    else TL(202.) {
        ro = vec3(-5., 1.0, 18.0);
        target = vec3(5.0, -1.0, 16.0);
        fov = 100. - t;
    }
    else TL(248.) {
    }
    else TL(256.) {
        ro = vec3(-5., 1.0, 18.0);
        target = vec3(5.0, -1.0, 16.0);
        fov = 100. - t;
    }
    else TL(292.) {
    }
    else TL(300.) {
        ro = vec3(-5., 1.0, 18.0);
        target = vec3(5.0, -1.0, 16.0);
        fov = 100. - t;
    }
    else TL(304.) {
    }
    else TL(320.) {
        ro = vec3(0., 1., -12.3);
        fov = 90. + t;
    }

    ro += 0.1 * fbm(vec2(beat / 4., 1.23));

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