#version 300 es
precision highp float;
precision highp int;
precision mediump sampler3D;

// #define AA

uniform vec3 iResolution;
uniform float iTime;
uniform sampler2D iChannel0; // first pass
uniform sampler2D iPrevPass;
uniform sampler2D iTextTexture;

void mainImage(out vec4 fragColor, in vec2 fragCoord);

out vec4 outColor;
void main(void) {
    vec4 c;
#ifdef AA
    vec4 t;
    c = vec4(0.0);
    for (int y = 0; y < 2; y++) {
        for (int x = 0; x < 2; x++) {
            vec2 sub = vec2(float(x), float(y)) * 0.5;  // FIXME
            vec2 uv = gl_FragCoord.xy + sub;
            mainImage(t, uv);
            c += 0.25 * t;
        }
    }
#else
    mainImage(c, gl_FragCoord.xy);
#endif
    outColor = c;
}

// consts
const float PI = 3.14159265359;
const float TAU = 6.28318530718;
const float PIH = 1.57079632679;

#define BPM 140.0
#define beat (iTime * BPM / 60.0)
#define saturate(x) clamp(x, 0., 1.)

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

vec3 tap4(sampler2D tex, vec2 uv, vec2 texelSize) {
    vec4 d = texelSize.xyxy * vec4(-1.0, -1.0, 1.0, 1.0);

    vec3 s;
    s = texture(tex, uv + d.xy).rgb;
    s += texture(tex, uv + d.zy).rgb;
    s += texture(tex, uv + d.xw).rgb;
    s += texture(tex, uv + d.zw).rgb;

    return s * (1.0 / 4.0);
}

vec2 textUv(vec2 uv, float id, vec2 p, float scale) {
    uv -= p;
    uv /= scale;

    float offset = 128.0 / 4096.0;
    float aspect = 2048.0 / 4096.0;
    uv.x = 0.5 + 0.5 * uv.x;
    uv.y = 0.5 - 0.5 * (aspect * uv.y + 1.0 - offset);
    uv.y = clamp(uv.y + offset * id, offset * id, offset * (id + 1.0));

    return uv;
}

