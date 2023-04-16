#version 300 es
precision highp float;
precision highp int;
precision mediump sampler3D;

// #define AA

uniform vec3 iResolution;
uniform float iTime;
uniform sampler2D iChannel0; // current pass
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

