vec4 prevColor;

// Hexagons - distance by iq
// https://www.shadertoy.com/view/Xd2GR3
// return: { 2d cell id (vec2), distance to border, distnace to center }
#define INV_SQRT3 0.5773503
vec4 hexagon(vec2 p) {
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

vec4 mapLayer0(vec3 pos) {
    vec4 m = vec4(999., 0., 0., 0.);
    vec3 p = pos;

    // ガーディアンのレーザーのチャージ
    if (beat >= 256. && beat < 324.) {
        p = pos - gurdian_pos - vec3(0, 0.12, gGuardianChargePosZ);
        float d = length(p) - gGuardianChargeRadius;

        if (beat < 264.) {
            p = abs(p);
            p += beat * 0.005;
            float a = 0.02;
            p = mod(p, a) - 0.5 * a;
            if (d < 0.05) d = min(d, length(p) - a * 0.7 * exp(-100. * d));
        }
        opU(m, d, M_LAZER, 1., gGuardianChargeBrightness);
    }

    // ガーディアンのレーザー
    if (beat >= 320. && beat < 328.) {
        p = pos - gurdian_pos;

        float x = easeInOutCubic(remapFrom(beat, 320., 328.));
        vec3 a = vec3(0, 0.12, gGuardianChargePosZ);
        vec3 b = a + vec3(0, 0, 6. * x);
        float d = sdCappedCylinder(p, a, b, 0.01 * x);
        opU(m, d, M_LAZER, 1., 10. * x);
    }

    return m;
}

vec4 mapLayer1(vec3 pos) {
    vec4 m = vec4(999., 0., 0., 0.);
    vec3 p = pos;

    // ボスのレーザー
    if (beat >= 172. && beat < 176.) {
        p = pos - boss_pos;
        vec3 dir = normalize(hash31(beat) - 0.5);
        dir = mix(dir, vec3(0, 0, -1), 0.3 + 0.7 * (beat - 172.) / 4.);
        vec3 a = 0.1 * dir;
        vec3 b = a + 3. * dir;
        float d = sdCappedCylinder(p, a, b, 0.0005);
        opU(m, d, M_LAZER, 0., 1.);
    }

    // ボスのバリア
    if (beat >= 280. && beat < 328.) {
        float size = 0.25 * easeInOutCubic(remapFrom(beat, 280., 296.));
        p = pos - boss_pos - vec3(0, 0, -0.1 - 0.5 * size);
        float d = sdBox(p, vec3(size, size, 0.001));
        vec4 h = hexagon(p.xy * mix(20., 5., remapFrom(beat, 324., 328.)));
        float emi = smoothstep(0.1, 0.0, h.z) * (0.2 + 2. * saturate(cos(beatTau / 4. + TAU * length(h.xy))));
        if (beat >= 312.) emi *= 0.1;
        if (beat >= 322.5) emi = mix(emi, 0.0, saturate((beat - 322.5) / 2.));
        opU(m, d, M_LAZER, 0., emi);
    }

    return m;
}

uniform float gFighterNameSeed; // 272

vec4 mapText(vec3 pos) {
    vec4 m = vec4(999., 0., 0., 0.);
    vec3 p = pos;

    // グリーティング
    vec3 fighter_group_pos = vec3(gFighterGroupPosX, gFighterGroupPosY, gFighterGroupPosZ);
    p = pos - fighter_group_pos;

    float a = 0.06;
    vec3 grid = floor(p / a + 0.5);
    p = opRepLim(p, a, vec3(7, 1, 4));
    vec2 rnd = hash23(grid);
    p.y -= 0.005 * sin(TAU * rnd.x + beatTau / 32.);

    vec3 p1 = p;
    p1.y -= 0.004;
    float b = 0.0018;
    float id;

    if (grid.y == -1. && grid.z == 4.) {
        id = 5. + mod(grid.x, 5.);
    } else {
        id = 10. + floor(hash23(grid * gFighterNameSeed).x * 17.);
    }

    float text = texture(iTextTexture, textUv(vec2(-p1.x, p1.y) / b, id, vec2(0), 8.0)).r;

    opU(m, sdBox(p1, vec3(b * 16., b, 0.01 * b)), M_NAME, 2. * text, 0.);

    return m;
}

float depth_max;

vec3 raymarch(vec3 ro, vec3 rd, vec3 bgcol, int layer) {
    vec3 col = bgcol;
    vec3 p;
    vec4 m;
    float t = 0.2;
    float eps;

    for (int i = ZERO; i < 200; i++) {
        p = ro + rd * t;

        if (layer == 0) {
            m = mapLayer0(p);
        } else {
            m = mapLayer1(p);
        }

        t += m.x;
        eps = t * 0.0005;
        if (m.x < eps || t >= prevColor.a) {
            break;
        }
    }

    float range = 4.5;

    if (sdBox(p, vec3(range)) < 0. && t < prevColor.a) {
        vec3 emissive = vec3(0.);

        if (m.y == M_LAZER) {
            emissive = mix(vec3(255, 79, 1) / 255., vec3(0.1, 0.1, 1), m.z) * 10. * m.w;
        } else if (m.y == M_NAME) {
            emissive = vec3(1) * m.z;
        }

        col += emissive;
    }

    if (m.w > 0.01) {
        depth = min(depth, t);
    }

    return col;
}

vec3 raymarchText(vec3 ro, vec3 rd, vec3 bgcol) {
    vec3 col = bgcol;
    vec3 p;
    vec4 m;
    float t = 0.;
    float eps;

    for (int i = ZERO; i < 100; i++) {
        p = ro + rd * t;
        m = mapText(p);
        t += m.x;
        eps = 0.00001;

        if (t >= prevColor.a) {
            break;
        }

        if (m.x < eps) {
            if (m.z > 0.01) {
                col += vec3(1) * m.z;
                depth = t;
                break;
            } else {
                t += eps * 100.;
            }
        }
    }

    return col;
}

void mainImage(out vec4 fragColor, vec2 fragCoord) {
    beat = gBeat;
    beatTau = beat * TAU;
    beatPhase = phase(beat / 2.);

    vec2 uv = fragCoord.xy / iResolution.xy;
    prevColor = texture(iPrevPass, uv);

    // Camera
    vec2 uv2 = (2. * fragCoord.xy - iResolution.xy) / iResolution.x;

    ro = vec3(gCameraEyeX, gCameraEyeY, gCameraEyeZ);
    target = vec3(gCameraTargetX, gCameraTargetY, gCameraTargetZ);
    fov = gCameraFov;

    vec3 up = vec3(0, 1, 0);
    vec3 fwd = normalize(target - ro);
    vec3 right = normalize(cross(up, fwd));
    up = normalize(cross(fwd, right));
    vec3 rd = normalize(right * uv2.x + up * uv2.y + fwd / tan(fov * TAU / 720.));

    boss_pos = vec3(gBossPosX, gBossPosY, gBossPosZ);
    gurdian_pos = vec3(gGuardianPosX, gGuardianPosY, gGuardianPosZ);

    depth = 999.;

    vec3 scol = raymarch(ro, rd, prevColor.rgb, 0);
    scol = raymarch(ro, rd, scol, 1);
    if (beat >= 92. && beat < 100.) scol = raymarchText(ro, rd, scol);
    scol = clamp(scol, 0.0, 100.0);

    fragColor = vec4(scol, min(depth, prevColor.a));
}