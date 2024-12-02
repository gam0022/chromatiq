vec4 prevColor;

vec2 greetingsUv(vec2 uv, float t, float scale)
{
    uv /= scale;
    float aspect = 2048.0 / TEXT_TEX_HEIGHT;
    uv.x = 0.5 + 0.5 * uv.x;
    uv.y = 0.5 - 0.5 * (aspect * uv.y) + t - 0.2;
    uv.y = clamp(uv.y, 128. * 27.0 / TEXT_TEX_HEIGHT, 1.);
    return uv;
}

void mainImage(out vec4 fragColor, vec2 fragCoord) {
    beat = gBeat;
    beatTau = beat * TAU;

    vec2 uv = fragCoord.xy / iResolution.xy;
    prevColor = texture(iPrevPass, uv);

    uv = (fragCoord * 2.0 - iResolution.xy) / min(iResolution.x, iResolution.y);

    vec3 col = prevColor.rgb;
    vec3 add = vec3(0.0);
    float a = 1.;
    float b = 0.;

    TL(328.) {}
    else TL(336.) {
        // TITLE
        add += texture(iTextTexture, textUv(uv, 0.0, vec2(0.0, 0.0), 3.0)).rgb;
        a = remap(t, 6., 8., 1., 0.);
    }
    else TL(344.) {
        // gam0022 & HAHAD
        add += texture(iTextTexture, textUv(uv, 1.0, vec2(-1.0, 0.1), 1.0)).rgb;
        add += texture(iTextTexture, textUv(uv, 2.0, vec2(-1.0, -0.1), 1.0)).rgb;

        add += texture(iTextTexture, textUv(uv, 3.0, vec2(1.0, 0.1), 1.0)).rgb;
        add += texture(iTextTexture, textUv(uv, 4.0, vec2(1.0, -0.1), 1.0)).rgb;
        a = remap(t, 6., 8., 1., 0.);
    }
    else TL(360.) {
        // greetings
        add += texture(iTextTexture, greetingsUv(uv, t / 12., 1.0)).rgb;
        a = remap(t, 15., 16., 1., 0.);
        b = remap(t, 9., 11., 0.7, 0.);
    }

    col = mix(col, vec3(0), b) + add * a;

    fragColor = vec4(col, prevColor.a);
}