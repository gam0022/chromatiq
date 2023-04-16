uniform float gCameraEyeX;     // -0.08828528243935951 -100 100 camera
uniform float gCameraEyeY;     // 3.5309297601209235 -100 100
uniform float gCameraEyeZ;     // -2.705631420983895 -100 100
uniform float gCameraTargetX;  // 0.7576763789243015 -100 100
uniform float gCameraTargetY;  // 3.4515422110479044 -100 100
uniform float gCameraTargetZ;  // -0.21633410393024527 -100 100
uniform float gCameraFov;      // 37.88049605411499 0 180

uniform float gUseBackbuffer;      // 0.5 0 1

#define opRep(p, a) p = mod(p, a) - a * 0.5
#define opRepLim(p, c, l) p = p - c * clamp(floor(p / c + 0.5), -l, l);

vec3 ro, target;
float fov;
vec3 scol;
// float beat;
float beatTau;
float beatPhase;

// Timeline
float prevEndTime = 0., t = 0.;
#define TL(beat, end) if (t = beat - prevEndTime, beat < (prevEndTime = end))

// Material Types
#define VOL 0.0
#define SOL 1.0

// https://www.shadertoy.com/view/3tX3R4
float remap(float val, float im, float ix, float om, float ox) { return clamp(om + (val - im) * (ox - om) / (ix - im), om, ox); }
float remap01(float val, float im, float ix) { return saturate((val - im) / (ix - im)); }

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

// https://www.shadertoy.com/view/lssGWn
float sdEgg(vec3 p, float r) {
    p.y *= 0.8;
    p.y += 0.15 * pow(1.5 * dot(p.xz, p.xz), 0.6);
    return length(p) - r;
}

float sdBox(vec3 p, vec3 b) {
    vec3 q = abs(p) - b;
    return length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0);
}

void rot(inout vec2 p, float a) { p *= mat2(cos(a), sin(a), -sin(a), cos(a)); }


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
    // p1.y += H;
    // opRep(p1.z, 2. * D);
    p1 -= vec3(8.5, 0.0, 4.5) * 0.2;
    
    vec4 ifs_p1 = vec4(1.57 / 4. + sin(beatPhase / 4.), 3.59 / 4., 0, 0);
    
    for(int i = 0; i < 4; i++){
        p1 = abs(p1 + vec3(8.5, 0.0, 4.5) * 0.2) - vec3(8.5, 0.0, 4.5) * 0.2;
        rot(p1.xz, TAU * ifs_p1.x);
        rot(p1.zy, TAU * ifs_p1.y);
    }

    //p1 *= 1.5;
    //p1.y -= 2.;

    
    opUnion(m, sdBox(p1, vec3(2, 5, 2)), SOL, roughness, 0.5);
    opUnion(m, sdBox(p1, vec3(0.1, 5, 2.1)), SOL, roughness + 1., 0.5 + step(16., beat) * fract(beat+length(p1)));
    //opUnion(m, sdBox(p1, vec3(2.0, 0.3, 2.01)), SOL, 1.1, 0.5);


    // background
    vec3 p2 = pos;
    // p2.y -= -H;
    p2 = abs(p2);
    // opUnion(m, sdBox(p2 + vec3(0, H, 0), vec3(W, a, D)), SOL, 0.6, 0.5);
    float th = -step(mod(beat, 8.), 4.);
    opUnion(m, sdBox(p2 - vec3(0, H, 0), vec3(W, a, D)), SOL, roughness + 0.*step(0., pos.y) * step(sin(p2.x), th), 10.0);
    opUnion(m, sdBox(p2 - vec3(0, 0, D), vec3(W, H, a)), SOL, roughness + step(sin(p2.y), 0.), 10.0);
    opUnion(m, sdBox(p2 - vec3(W, 0, 0), vec3(a, H, D)), SOL, roughness + step(sin(p2.z), th), 10.0);

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
    beatPhase = floor(beat)+(.5+.5*cos(TAU * .5 * exp(-5.0*fract(beat))));

    vec2 uv = fragCoord.xy / iResolution.xy;

    // Camera
    vec2 noise = hash23(vec3(iTime, fragCoord)) - 0.5;  // AA
    vec2 uv2 = (2. * (fragCoord.xy + noise) - iResolution.xy) / iResolution.x;

    float FD = 675. * 3.;  // Final Room Depth
    fov = 80.;

#define DEBUG_CAMERA
#ifdef DEBUG_CAMERA
    setCamera(abs(vec4(538, 291, 831, 300)), 3.0);
    // setCameraRot(abs(iMouse), 3.);
#else

    // Room1
    TL(beat, 4. * 8.) setCamera(vec4(600, 250. + t * 3., 600, 243. - t * 6.), 3.);
    else TL(beat, 4. * 10.) setCamera(vec4(600, 307, 600, 44. + t * 4.), 3.);
    else TL(beat, 4. * 12.) setCamera(vec4(494, 322, 695, 216), 2.4 + 0.2 * t);
    else TL(beat, 4. * 14.) setCamera(vec4(600, 481. + 10. * t, 600, 59), 3.);
    else TL(beat, 4. * 16.) setCamera(vec4(909, 158. - 10.0 * t, 470. + 10.0 * t, 158), 3.);
    else TL(beat, 4. * 18.) setCamera(vec4(541, 335., 609., 384. + 2.0 * t), 3.);

    else TL(beat, 4. * 72.) {
        setCamera(vec4(645, 326., 705., FD + 272.), 1.9);
        fov = mix(90., 120., exp(-t));
    }
    
    setCamera(vec4(538, 291, 831, 492), 5.);

#endif

    vec3 up = vec3(0, 1, 0);
    vec3 fwd = normalize(target - ro);
    vec3 right = normalize(cross(up, fwd));
    up = normalize(cross(fwd, right));
    vec3 rd = normalize(right * uv2.x + up * uv2.y + fwd / tan(fov * TAU / 720.));

//#define DEBUG_SCENE
#ifdef DEBUG_SCENE
    raymarching(ro, rd);
    fragColor = vec4(scol, 1.);
#else
    madtracer(ro, rd, hash12(uv2));
    vec3 bufa = texture(iChannel0, uv).xyz;

    if (uv.x > gUseBackbuffer) bufa *= 0.;
    
    // fade out
    // scol = mix(scol, vec3(0), remap01(beat, 4. * 70., 4. * 72.));
    
    fragColor = saturate(vec4(1. * scol + 0.0 * bufa, 0.));
#endif
}