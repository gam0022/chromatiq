#version 300 es
precision highp float;
precision highp int;
precision mediump sampler3D;

// #define AA

uniform vec3 iResolution;
uniform float iTime;
uniform float iFrame;
uniform sampler2D iChannel0; // first pass
uniform sampler2D iPrevPass;
uniform sampler2D iTextTexture;


uniform float gCameraEyeX;     // -0.08828528243935951 -100 100 camera
uniform float gCameraEyeY;     // 3.5309297601209235 -100 100
uniform float gCameraEyeZ;     // -2.705631420983895 -100 100
uniform float gCameraTargetX;  // 0.7576763789243015 -100 100
uniform float gCameraTargetY;  // 3.4515422110479044 -100 100
uniform float gCameraTargetZ;  // -0.21633410393024527 -100 100
uniform float gCameraFov;      // 37.88049605411499 0 180
uniform float gCameraDebug;    // 0 0 1

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

/*

// https://www.shadertoy.com/view/lsf3WH
// Noise - value - 2D by iq
float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash12(i + vec2(0.0, 0.0)), hash12(i + vec2(1.0, 0.0)), u.x), mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 uv) {
    float f = 0.0;
    mat2 m = mat2(1.6, 1.2, -1.2, 1.6);
    f = 0.5000 * noise(uv);
    uv = m * uv;
    f += 0.2500 * noise(uv);
    uv = m * uv;
    f += 0.1250 * noise(uv);
    uv = m * uv;
    f += 0.0625 * noise(uv);
    uv = m * uv;
    return f;
}

*/

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
