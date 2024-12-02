#version 300 es
precision highp float;
precision highp int;
precision mediump sampler3D;

uniform vec3 iResolution;
uniform float iTime;
uniform float iFrame;
uniform sampler2D iChannel0;  // first pass
uniform sampler2D iPrevPass;
uniform sampler2D iTextTexture;

uniform float gCameraFov;      // 37 0 180 camera
uniform float gCameraEyeX;     // 0
uniform float gCameraEyeY;     // 3.5
uniform float gCameraEyeZ;     // -2
uniform float gCameraTargetX;  // 0
uniform float gCameraTargetY;  // 2
uniform float gCameraTargetZ;  // 0
uniform float gCameraDebug;    // 0 0 1

void mainImage(out vec4 fragColor, in vec2 fragCoord);

out vec4 outColor;
void main(void) {
    vec4 c;
    mainImage(c, gl_FragCoord.xy);
    outColor = c;
}

vec3 tap4(sampler2D tex, vec2 uv, vec2 texelSize) {
    vec4 d = texelSize.xyxy * vec4(-1.0, -1.0, 1.0, 1.0);

    vec3 s;
    s = texture(tex, uv + d.xy).rgb;
    s += texture(tex, uv + d.zy).rgb;
    s += texture(tex, uv + d.xw).rgb;
    s += texture(tex, uv + d.zw).rgb;

    return s * (1.0 / 4.0);
}

#define TEXT_TEX_HEIGHT 8096.0

vec2 textUv(vec2 uv, float id, vec2 p, float scale) {
    uv -= p;
    uv /= scale;

    float offset = 128.0 / TEXT_TEX_HEIGHT;
    float aspect = 2048.0 / TEXT_TEX_HEIGHT;
    uv.x = 0.5 + 0.5 * uv.x;
    uv.y = 0.5 - 0.5 * (aspect * uv.y + 1.0 - offset);
    uv.y = clamp(uv.y + offset * id, offset * id, offset * (id + 1.0));

    return uv;
}

const float PI = 3.14159265359;
const float TAU = 6.28318530718;
#define saturate(x) clamp(x, 0., 1.)
#define tri(x) (1. - 4. * abs(fract(x) - .5))
#define phase(x) (floor(x) + .5 + .5 * cos(TAU * .5 * exp(-5. * fract(x))))
void rot(inout vec2 p, float a) { p *= mat2(cos(a), sin(a), -sin(a), cos(a)); }

vec2 pmod(vec2 p, float s, out float id) {
    float a = PI / s - atan(p.x, p.y);
    float n = TAU / s;
    id = floor(a / n);
    a = id * n;
    rot(p, a);
    return p;
}

float clamp2(float x, float min, float max) { return (min < max) ? clamp(x, min, max) : clamp(x, max, min); }
float remap(float val, float im, float ix, float om, float ox) { return clamp2(om + (val - im) * (ox - om) / (ix - im), om, ox); }
float remapFrom(float val, float im, float ix) { return remap(val, im, ix, 0.0, 1.0); }  // TODO: optimize
float remapTo(float val, float om, float ox) { return remap(val, 0.0, 1.0, om, ox); }    // TODO: optimize
float easeInOutCubic(float t) { return t < 0.5 ? 4.0 * t * t * t : (t - 1.0) * (2.0 * t - 2.0) * (2.0 * t - 2.0) + 1.0; }

#define ZERO (min(int(iFrame), 0))

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

vec3 hash31(float p) {
    vec3 p3 = fract(vec3(p) * vec3(.1031, .1030, .0973));
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.xxy + p3.yzz) * p3.zyx);
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

float noise(vec3 x) {
    vec3 p = floor(x);
    vec3 f = fract(x);

    f = f * f * (3.0 - 2.0 * f);

    float n = p.x + p.y * 57.0 + 113.0 * p.z;

    float res = mix(mix(mix(hash11(n + 0.0), hash11(n + 1.0), f.x), mix(hash11(n + 57.0), hash11(n + 58.0), f.x), f.y),
                    mix(mix(hash11(n + 113.0), hash11(n + 114.0), f.x), mix(hash11(n + 170.0), hash11(n + 171.0), f.x), f.y), f.z);
    return res;
}

float voronoi(vec2 uv) {
    vec2 i = floor(uv);
    vec2 f = fract(uv);
    vec2 res = vec2(8, 8);

    for (int x = -1; x <= 1; x++) {
        for (int y = -1; y <= 1; y++) {
            vec2 n = vec2(x, y);
            vec2 np = hash22(i + n);
            vec2 p = n + np - f;

            // マンハッタン距離
            // float d = abs(p.x) + abs(p.y);
            float d = length(p);
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

float fbm(vec3 p, int oct) {
    float f;
    f = 0.50000 * noise(p);
    p = p * 2.02;
    if (oct >= 2) f += 0.25000 * noise(p);
    p = p * 2.23;
    if (oct >= 3) f += 0.12500 * noise(p);
    p = p * 2.41;
    if (oct >= 4) f += 0.06250 * noise(p);
    p = p * 2.62;
    if (oct >= 5) f += 0.03125 * noise(p);
    return f;
}

float fbmVoronoi(vec2 p) {
    float f;
    f = 0.50000 * voronoi(p);
    p = p * 2.02;
    f += 0.25000 * voronoi(p);
    p = p * 2.23;
    f += 0.12500 * voronoi(p);
    p = p * 2.41;
    f += 0.06250 * voronoi(p);
    p = p * 2.62;
    f += 0.03125 * voronoi(p);
    return f;
}

uniform float gBeat;  // 0 0 364 Main
uniform float gBPM;   // 0 1 200

// global vars
vec3 ro, target;
float fov;
float beat, beatTau, beatPhase;

float depth;

// シーン依存
int scene_id;
vec3 sundir = normalize(vec3(0.1, 0.1, -1.0));
vec3 lightColorDirectional = vec3(0.9, 0.8, 1.);
vec3 lightColorAmbient = 3. * vec3(0.9, 0.8, 1.);

vec3 boss_pos;
vec3 gurdian_pos;

// Timeline
float prevEndTime = 0., t = 0.;
#define TL(end) if (t = beat - prevEndTime, beat < (prevEndTime = end))

// Materials
#define M_CITY 0.
#define M_GUARDIAN 1.
#define M_FIGHTER 2.
#define M_LAVA 3.
#define M_BOSS 4.
#define M_BOSS_EYE 5.
#define M_EXPLOSION 6.
#define M_LAZER 7.
#define M_NAME 8.

#define opRepLim(p, s, l) p - s* clamp(round(p / s), -l, l)

void opU(inout vec4 m, float d, float mat_id, float param0, float param1) {
    if (d < m.x) m = vec4(d, mat_id, param0, param1);
}

float opSmoothUnion(float d1, float d2, float k) {
    float h = clamp(0.5 + 0.5 * (d2 - d1) / k, 0.0, 1.0);
    return mix(d2, d1, h) - k * h * (1.0 - h);
}

float sdBox(vec3 p, vec3 b) {
    vec3 q = abs(p) - b;
    return length(max(q, 0.)) + min(max(q.x, max(q.y, q.z)), 0.);
}

float sdBox(vec2 p, vec2 b) {
    vec2 q = abs(p) - b;
    return length(max(q, 0.)) + min(max(q.x, q.y), 0.);
}

float sdTorus(vec3 p, vec2 t) {
    vec2 q = vec2(length(p.xz) - t.x, p.y);
    return length(q) - t.y;
}

float sdCappedCylinder(vec3 p, vec3 a, vec3 b, float r) {
    vec3 ba = b - a;
    vec3 pa = p - a;
    float baba = dot(ba, ba);
    float paba = dot(pa, ba);
    float x = length(pa * baba - ba * paba) - r * baba;
    float y = abs(paba - baba * 0.5) - baba * 0.5;
    float x2 = x * x;
    float y2 = y * y * baba;
    float d = (max(x, y) < 0.0) ? -min(x2, y2) : (((x > 0.0) ? x2 : 0.0) + ((y > 0.0) ? y2 : 0.0));
    return sign(d) * sqrt(abs(d)) / baba;
}

uniform float gGuardianPosX;       // 0
uniform float gGuardianPosY;       // -0.5
uniform float gGuardianPosZ;       // 0
uniform float gGuardianIteration;  // 6
uniform float gGuardianIfsRotZ;    // 0.65

uniform float gGuardianChargePosZ;        // 0.13
uniform float gGuardianChargeRadius;      // 0.02
uniform float gGuardianChargeBrightness;  // 1

uniform float gBossPosX;        // 0
uniform float gBossPosY;        // 0.2
uniform float gBossPosZ;        // 0
uniform float gBossIfsOffsetX;  // 1.79

uniform float gFighterGroupPosX;  // 0
uniform float gFighterGroupPosY;  // 0.2
uniform float gFighterGroupPosZ;  // -1

float sunColor(vec3 rd) { return saturate(dot(sundir, rd)); }

vec3 skyColor(vec3 rd) {
    if (scene_id == 0) {
        float sun = sunColor(rd);
        vec3 bgcol = vec3(0.56, 0.55, 0.95);
        bgcol -= 0.6 * vec3(0.90, 0.75, 0.95) * rd.y;
        bgcol += 0.2 * vec3(1.00, 0.60, 0.10) * pow(sun, 8.0);
        return bgcol;
    } else {
        return vec3(0.0, 0.0, 0.0);
    }
}
