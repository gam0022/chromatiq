
uniform float gCameraEyeX;     // -0.08828528243935951 -100 100 camera
uniform float gCameraEyeY;     // 3.5309297601209235 -100 100
uniform float gCameraEyeZ;     // -2.705631420983895 -100 100
uniform float gCameraTargetX;  // 0.7576763789243015 -100 100
uniform float gCameraTargetY;  // 3.4515422110479044 -100 100
uniform float gCameraTargetZ;  // -0.21633410393024527 -100 100
uniform float gCameraFov;      // 37.88049605411499 0 180
uniform float gCameraDebug;    // 0 0 1

#define opRep(p, a) p = mod(p, a) - a * 0.5
#define opRepLim(p, c, l) p = p - c * clamp(floor(p / c + 0.5), -l, l);

#define tri(x) (1. - 4. * abs(fract(x) - 0.5))
#define phase(x) (floor(x) + .5 + .5 * cos(PI * exp(-5.0 * fract(x))))
#define phase2(x, y) (floor(x) + .5 + .5 * cos(PI * exp(-y * fract(x))))

vec3 ro, target;
float fov;
vec3 scol;
float beatTau;
float beatPhase;
vec3 boxPos;

// Timeline
float prevEndTime = 0., t = 0.;
#define TL(beat, end) if (t = beat - prevEndTime, beat < (prevEndTime = end))

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
    return mix(col, vec3(1), 0.1 * floor(m.w));
}

// Ref. Energy Lab by kaneta
// https://www.shadertoy.com/view/3dd3WB
float smoothPulse(float start, float end, float period, float smoothness, float t) {
    float h = abs(end - start) * 0.5;
    t = mod(t, period);
    return smoothstep(start, start + h * smoothness, t) - smoothstep(end - h * smoothness, end, t);
}

float sdBox(vec3 p, vec3 b) {
    vec3 q = abs(p) - b;
    return length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0);
}

void rot(inout vec2 p, float a) { p *= mat2(cos(a), sin(a), -sin(a), cos(a)); }

int bytebeat(int t){
    return
    ((t<<1)^((t<<1)+(t>>7)&t>>12))|t>>(4-(1^7&(t>>19)))|t>>7;//http://canonical.org/~kragen/bytebeat/
    //(t|(t>>9|t>>7))*t&(t>>11|t>>9);
}
float fbytebeat(float t){
    return mod(float(bytebeat(int(t))),256.)/255.;
}

vec4 map(vec3 pos) {
    vec4 m = vec4(2, VOL, 0, 0);
    // x: Distance
    // y: MaterialType (VOL or SOL)
    // z: Roughness in (0-1), Emissive when z>1
    // w: ColorPalette

    float roughness = 0.05;
    float a = .1;
    float W = 16.;
    float H = 8.;
    float D = 32.;

    vec3 p1 = pos;

    boxPos = vec3(0);
    if (beat < 22.)
        boxPos.y = -12.;
    else if (beat < 40.)
        boxPos.y = -10. + (beat - 24.) / 2.;

    vec4 _IFS_Rot = vec4(0.34 + beatPhase / 2.3, -0.28, 1.03, 0.);
    vec4 _IFS_Offset = vec4(1.36, 0.06, 0.69, 1.);
    float _IFS_Iteration = phase2(tri(beat / 16.) + 2., 5.);
    // _IFS_Iteration = 3.;
    vec4 _IFS_BoxBase = vec4(1, 1, 1, 0);
    vec4 _IFS_BoxEmissive = vec4(0.05, 1.05, 1.05, 0);

    if (beat < 48.) {
        _IFS_Rot *= 0.;
        _IFS_Offset *= 0.;
        _IFS_Iteration = 1.;
    } else if (beat < 60.) {
        float a = saturate(phase((beat - 48.) / 4.));
        _IFS_Iteration = 1. + a;
        _IFS_Offset = vec4(1.36, 0.06, 0.69, 1.) * a;
    } else if (beat < 80.) {
    } else {
        //_IFS_Offset *= 2. * hash11(floor(beat) * 0.3123);
        //_IFS_Rot = vec4(0.34 + sin(beatPhase), -0.28, 1.03, 0.);
    }

    // _IFS_Iteration = 4.;

    p1 -= (boxPos + _IFS_Offset.xyz);

    vec3 pp1 = p1;

    for (int i = 0; i < int(_IFS_Iteration); i++) {
        pp1 = p1 + +_IFS_Offset.xyz;
        p1 = abs(p1 + _IFS_Offset.xyz) - _IFS_Offset.xyz;
        rot(p1.xz, TAU * _IFS_Rot.x);
        rot(p1.zy, TAU * _IFS_Rot.y);
        rot(p1.xy, TAU * _IFS_Rot.z);
    }

    float emi = 1.1 * abs(cos((beatTau - p1.y) / 4.));
    if (mod(beat, 8.) > 4.) emi = 1.1 * saturate(sin(beatTau * 4.));

    float hue = 0.5;
    if (beat < 96.)
        hue = 0.5;
    else if (beat < 120.)
        hue = fract(beat + length(p1));
    else
        hue = 0.0;

    opUnion(m, sdBox(p1, _IFS_BoxBase.xyz), SOL, roughness, 0.5);
    opUnion(m, sdBox(p1, _IFS_BoxEmissive.xyz), SOL, emi, hue);
    opUnion(m, sdBox(p1, _IFS_BoxEmissive.yzx), SOL, emi, hue);

    vec4 mp = vec4(2, VOL, 0, 0);
    opUnion(mp, sdBox(pp1, _IFS_BoxBase.xyz), SOL, roughness, 0.5);
    opUnion(mp, sdBox(pp1, _IFS_BoxEmissive.xyz), SOL, emi, hue);
    opUnion(mp, sdBox(pp1, _IFS_BoxEmissive.yzx), SOL, emi, hue);

    m = mix(mp, m, fract(_IFS_Iteration));

    // room
    vec3 p2 = abs(pos);
    float hole = sdBox(pos - vec3(0., -H - 0.5, 0.), vec3(1.1) * smoothstep(4., 12., beat));

    // floor and ceil
    if (beat < 60.) emi = step(0., pos.y) * step(p2.x, 2.) * step(p2.z, 8.) * floor(mod(pos.x, 2.0));
    else emi = 0.;
    opUnion(m, max(sdBox(p2 - vec3(0, H + 4., 0), vec3(W, 4., D)), -hole), SOL, roughness + emi, 10.0);

    // door
    emi = step(p2.x, 2.) * step(p2.y, 2.);
    if (mod(beat, 2.) < 1. && beat < 80.) emi = 1. - emi;
    opUnion(m, sdBox(p2 - vec3(0, 0, D), vec3(W, H, a)), SOL, roughness + emi, 10.0);

    // left right wall
    float id = floor((pos.z + D) / 4.);
    emi = step(1., mod(id, 2.));

    if (beat < 32.)
        emi *= sin(beat * 48.);
    else if (beat < 48.)
        emi *= 1.;
    else if (beat < 120.)
        emi *= step(id, mod(beat * 4., 16.));
    else
        emi = step(.5, hash12(floor(pos.yz) + 123.23 * floor(beat * 2.)));
    opUnion(m, sdBox(p2 - vec3(W, 0, 0), vec3(a, H, D)), SOL, roughness + emi, 10.0);

    // camera light
    // vec3 light = ro - normalize(target - ro) * 3.0;
    // opUnion(m, length(pos - light) - 1.0, SOL, 1.1, 10.0);

    return m;
}

vec3 normal(vec3 p) {
    vec2 e = vec2(0, .05);
    return normalize(map(p).x - vec3(map(p - e.yxx).x, map(p - e.xyx).x, map(p - e.xxy).x));
}

// Ref. EOT - Grid scene by Virgill
// https://www.shadertoy.com/view/Xt3cWS
void madtracer(vec3 ro1, vec3 rd1, float seed) {
    scol = vec3(0);
    float t = 0., t2 = 0.;
    vec4 m1, m2;
    vec3 rd2, ro2, nor2;
    for (int i = 0; i < 160; i++) {
        m1 = map(ro1 + rd1 * t);
        // t += m1.y == VOL ? 0.25 * abs(m1.x) + 0.0008 : 0.25 * m1.x;
        t += 0.25 * mix(abs(m1.x) + 0.0032, m1.x, m1.y);
        ro2 = ro1 + rd1 * t;
        nor2 = normal(ro2);
        rd2 = mix(reflect(rd1, nor2), hashHs(nor2, vec3(seed, i, iTime)), saturate(m1.z));
        m2 = map(ro2 + rd2 * t2);
        // t2 += m2.y == VOL ? 0.25 * abs(m2.x) : 0.25 * m2.x;
        t2 += 0.25 * mix(abs(m2.x), m2.x, m2.y);
        scol += .007 * (pal(m2) * step(1., m2.z) + pal(m1) * step(1., m1.z));

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
        m = map(p);
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

void setCamera(vec4 v, float roY) {
    vec4 u = v / vec2(1200, 675).xyxy;
    vec4 n = u * 2. - 1.;
    ro = vec3(8. * n.z, roY, -64. * u.w);
    target = ro + vec3(2. * n.xy, 1);
}

void setCameraRot(vec4 v, float roY) {
    vec4 u = v / vec2(1200, 675).xyxy;
    vec4 n = u * 2. - 1.;
    ro = vec3(8. * n.z, roY, 16. * u.w);
    vec3 fwd = vec3(0, 0, 1);
    rot(fwd.xz, n.x * TAU / 2.);
    rot(fwd.yz, n.y * TAU / 4.);
    target = ro + fwd;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    // beat = iTime * BPM / 60.0;
    beatTau = beat * TAU;
    beatPhase = phase(beat / 2.);

    vec2 uv = fragCoord.xy / iResolution.xy;

    // Camera
    vec2 noise = hash23(vec3(iTime, fragCoord)) - 0.5;  // AA
    vec2 uv2 = (2. * (fragCoord.xy + noise) - iResolution.xy) / iResolution.x;

    // Timeline
    TL(beat, 8.) {
        ro = vec3(9.5, -1.36, -12.3 + t * .3);
        target = vec3(0.0, -2.19, 0.0);
        fov = 100.;
    }
    else TL(beat, 16.) {
        ro = vec3(5.5, -5, -1.2);
        target = vec3(0., -8., -0.);
        fov = 100.0 + t;
    }
    else TL(beat, 24.) {
        ro = vec3(5.5, -5, -1.2);
        target = vec3(0., -8., -0.);
        fov = 60.0 + t;
    }
    else TL(beat, 40.) {
        ro = vec3(10.8, -4.2, -7.2 + t * .1);
        target = vec3(0., -5., -0.);
        fov = 93.77124567016284;
    }
    else {
        float dice = hash11(floor(beat / 4. + 2.) * 123.);
        if (dice < 0.8)
            ro = vec3(8. * cos(beatTau / 128.), mix(-6., 6., dice), 8. * sin(beatTau / 128.));
        else
            ro = vec3(9.5 - dice * 20., 1., -12.3);

        target = boxPos;
        fov = 120.;
    }

    if (beat < 120.0)
        0.;
    else
        ro += 4. * fbm(vec2(beat / 4., 1.23));

    if (gCameraDebug > 0.) {
        ro = vec3(gCameraEyeX, gCameraEyeY, gCameraEyeZ);
        target = vec3(gCameraTargetX, gCameraTargetY, gCameraTargetZ);
        fov = gCameraFov;
    }

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
    // scol = mix(scol, vec3(0), remap01(beat, 4. * 70., 4. * 72.));
    fragColor = saturate(vec4(0.7 * scol + 0.7 * bufa, 0.));
#endif
}