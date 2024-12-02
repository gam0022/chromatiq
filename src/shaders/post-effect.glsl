uniform float gChromaticAberrationIntensity;  // 0 0 0.1 post
uniform float gChromaticAberrationDistance;   // 0 0 1

uniform float gVignetteIntensity;   // 1 0 3
uniform float gVignetteSmoothness;  // 1.6 0 5
uniform float gVignetteRoundness;   // 1 0 1

uniform float gTonemapExposure;  // 1.5 0.0 2
uniform float gFlash;            // 0 0 1
uniform float gFlashSpeed;       // 0 0 60
uniform float gBlend;            // 0 -1 1

uniform float gGlitchIntensity;  // 0 0 0.1
uniform float gXSfhitGlitch;     // 0 0 0.1
uniform float gInvertRate;       // 0 0 1

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

float vignette(vec2 uv) {
    vec2 d = abs(uv - 0.5) * gVignetteIntensity;
    float roundness = (1.0 - gVignetteRoundness) * 6.0 + gVignetteRoundness;
    d = pow(d, vec2(roundness));
    return pow(saturate(1.0 - dot(d, d)), gVignetteSmoothness);
}

// vec3 acesFilm(const vec3 x) {
//     const float a = 2.51;
//     const float b = 0.03;
//     const float c = 2.43;
//     const float d = 0.59;
//     const float e = 0.14;
//     return clamp((x * (a * x + b)) / (x * (c * x + d) + e), 0.0, 1.0);
// }

vec3 invert(vec3 c, vec2 uv) {
    if (hash12(vec2(floor(uv.y * gInvertRate * 32.0), beat)) < gInvertRate) {
        return vec3(1.0) - c;
    } else {
        return c;
    }
}

vec3 flash(vec3 c) {
    c = mix(c, vec3(1.0), gFlash * saturate(cos(iTime * PI * .5 * gFlashSpeed)));
    return c;
}

vec3 chromaticAberration(vec2 uv) {
    uv.x += gXSfhitGlitch * (fbm(vec2(232.0 * uv.y, gBeat)) - 0.5);

    vec2 d = abs(uv - 0.5);
    float f = mix(0.5, dot(d, d), gChromaticAberrationDistance);
    f *= f * gChromaticAberrationIntensity;
    vec2 shift = vec2(f);

    float a = 2.0 * hash11(gBeat) - 1.0;
    vec2 grid = hash23(vec3(floor(vec2(uv.x * (4.0 + 8.0 * a), (uv.y + a) * 32.0)), gBeat));
    grid = 2.0 * grid - 1.0;
    shift += gGlitchIntensity * grid;

    vec3 col;
    col.r = texture(iPrevPass, uv + shift).r;
    col.g = texture(iPrevPass, uv).g;
    col.b = texture(iPrevPass, uv - shift).b;
    return col;
}

vec3 blend(vec3 c) {
    c = mix(c, vec3(1.0), saturate(gBlend));
    c = mix(c, vec3(0.0), saturate(-gBlend));
    return c;
}

// https://github.com/KhronosGroup/ToneMapping/blob/main/PBR_Neutral/pbrNeutral.glsl
vec3 PBRNeutralToneMapping(vec3 color) {
    const float startCompression = 0.8 - 0.04;
    const float desaturation = 0.15;

    float x = min(color.r, min(color.g, color.b));
    float offset = x < 0.08 ? x - 6.25 * x * x : 0.04;
    color -= offset;

    float peak = max(color.r, max(color.g, color.b));
    if (peak < startCompression) return color;

    const float d = 1. - startCompression;
    float newPeak = 1. - d * d / (peak + d - startCompression);
    color *= newPeak / peak;

    float g = 1. - 1. / (desaturation * (peak - newPeak) + 1.);
    return mix(color, newPeak * vec3(1, 1, 1), g);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    // vec3 col = texture(iPrevPass, uv).rgb;
    vec3 col = chromaticAberration(uv);
    col = PBRNeutralToneMapping(col * gTonemapExposure);
    col *= vignette(uv);
    col = invert(col, uv);
    col = flash(col);
    col = blend(col);
    // col = pow(col, vec3(1.0 / 2.2));
    fragColor = vec4(col, 1.0);
}
