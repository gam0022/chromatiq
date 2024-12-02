float DBFold(vec3 p, float fo, float g, float w) {
    if (p.z > p.y) p.yz = p.zy;
    float vx = p.x - 2. * fo;
    float vy = p.y - 4. * fo;
    float v = max(abs(vx + fo) - fo, vy);
    float v1 = max(vx - g, p.y - w);
    v = min(v, v1);
    v1 = max(v1, -abs(p.x));
    return min(v, p.x);
}

vec3 DBFoldParallel(vec3 p, vec3 fo, vec3 g, vec3 w) {
    vec3 p1 = p;
    p.x = DBFold(p1, fo.x, g.x, w.x);
    p.y = DBFold(p1.yzx, fo.y, g.y, w.y);
    p.z = DBFold(p1.zxy, fo.z, g.z, w.z);
    return p;
}

vec4 orbitTrap;

// https://www.shadertoy.com/view/MdV3Wz
float dMandelBox(vec3 p, float _Scale, float _MinRad2, float _sr, vec3 _fo, vec3 _gh, vec3 _gw) {
    vec4 JC = vec4(p, 1.);
    float r2 = dot(p, p);
    float dd = 1.;
    orbitTrap = vec4(10000);

    for (int i = ZERO; i < 6; i++) {
        p = p - clamp(p.xyz, -1.0, 1.0) * 2.0;  // mandelbox's box fold

        // Apply pull transformation
        vec3 signs = sign(p);  // Save 	the original signs
        p = abs(p);
        p = DBFoldParallel(p, _fo, _gh, _gw);

        p *= signs;  // resore signs: this way the mandelbrot set won't extend in negative directions

        // Sphere fold
        r2 = dot(p, p);
        float t = clamp(1. / r2, 1., 1. / _MinRad2);
        p *= t;
        dd *= t;

        // Scale and shift
        p = p * _Scale + JC.xyz;
        dd = dd * _Scale + JC.w;
        p = vec3(1.0, 1.0, .92) * p;

        r2 = dot(p, p);
        orbitTrap = min(orbitTrap, abs(vec4(p, r2)));
    }

    dd = abs(dd);

#if 0
    return (sqrt(r2) - _sr) / dd;  // bounding volume is a sphere
#else
    p = abs(p);
    return (max(p.x, max(p.y, p.z)) - _sr) / dd;  // bounding volume is a cube
#endif
}

vec4 mGuardian(vec3 pos, vec4 m) {
    vec3 p = pos;
    float scale = 0.01;
    float _IFS_Iteration = gGuardianIteration;

    // bounds sphere
    float dist = length(p - vec3(0, 10, 0) * scale);
    float _BoundsRadius = (15. + 2. * (_IFS_Iteration - 6.)) * scale;

    if (dist >= _BoundsRadius + scale) {
        opU(m, dist - _BoundsRadius, M_GUARDIAN, 0.0, 0.);
        return m;
    }

    // main
    p /= scale;

    vec3 p0 = p;
    p0.y -= 22.;
    float d = sdTorus(p0, vec2(7., 0.1));
    opU(m, d * scale, M_GUARDIAN, 2., 0.);

    rot(p.xz, TAU / 4.);

    vec3 _IFS_Rot = vec3(0.34, 0.85, gGuardianIfsRotZ);
    vec3 _IFS_Offset = vec3(0.66, 9.0, 1.5);

    vec3 p1 = p - _IFS_Offset;
    vec3 pp1 = p1;

    for (int i = ZERO; i < int(_IFS_Iteration); i++) {
        pp1 = p1;
        p1 = abs(p1 + _IFS_Offset.xyz) - _IFS_Offset.xyz;
        rot(p1.xz, TAU * _IFS_Rot.x);
        rot(p1.zy, TAU * _IFS_Rot.y);
        rot(p1.xy, TAU * _IFS_Rot.z + 0.0 * sin(beatPhase * TAU / 4.9));
    }

    float d1 = sdBox(p1, vec3(0.5, 2, 0.5));
    float d2 = sdBox(p1, vec3(0.6, 2.1, 0.1));

    float dp1 = sdBox(pp1, vec3(0.5, 2, 0.5));
    float dp2 = sdBox(pp1, vec3(0.6, 2.1, 0.1));

    d1 = mix(dp1, d1, fract(_IFS_Iteration));
    d2 = mix(dp2, d2, fract(_IFS_Iteration));

    opU(m, d1 * scale, M_GUARDIAN, 0.0, 0.);

    float emi = 0.;
    if (beat < 320.) emi = 10. * smoothstep(258., 260., beat) * saturate(cos(beatTau * 0.25 + 100.0 * length(pos - vec3(0, 0.12, 0.3))));
    opU(m, d2 * scale, M_GUARDIAN, 1.0, emi);

    // 下半分をカット
    m.x = max(m.x, -pos.y);

    return m;
}

vec3 TrackPath(float t) { return vec3(4.7 * sin(t * 0.15) + 2.7 * cos(t * 0.19), 0., t); }

// https://www.shadertoy.com/view/XsfBWM
float dCave(vec3 p) {
    vec3 p0 = p;

    float d;
    p.xy -= TrackPath(p.z).xy;
    p += 0.1 * (1. - cos(2. * PI * (p + 0.2 * (1. - cos(2. * PI * p.zxy)))));
    vec3 hv = cos(0.6 * p - 0.5 * sin(1.4 * p.zxy + 0.4 * cos(2.7 * p.yzx)));
    d = 0.9 * (length(hv) - 1.1);

    if (d < 0.1) {
        d += 0.1 * fbm(p, 5);
    }

    return d;
}

float dLava(vec3 p) {
    float d = p.y;
    p.xz -= 0.2 * (sin(p.x + 0.1 * beat) + sin(p.z + 0.1 * beat));
    d += 0.01 * (sin(p.x * 2. - 0.1 * beat) + sin(2. * p.z - 0.1 * beat));
    d += 0.005 * (sin(4.32 * p.x - 0.05 * beat) + sin(4.32 * p.z - 0.05 * beat));
    d += 0.1 * saturate(1.0 / (0.0001 + length(p.xz)));

    if (d < 0.1) {
        d += 0.05 * fbmVoronoi(p.xz);
    }

    return d;
}

uniform float gBossWingSpeed;  // 1 0 10
uniform float gBossEmissive;   // 2 0 10

vec4 mBoss(vec3 pos, vec4 m) {
    int _IFS_Iteration = 5;
    vec3 _IFS_Offset = vec3(gBossIfsOffsetX, 2.42, -0.5);
    float scale = 0.01;

    if (scene_id == 1) {
        _IFS_Iteration = 4;

        if (beat < 44.) {
            scale = 0.15;
        } else {
            float x = remapFrom(beat, 44., 60.);
            scale = mix(0.2, 0.4, x);
            _IFS_Offset.z = mix(-0.5, 0.0, x);
        }
    }

    vec3 p = pos;

    // bounds sphere
    float dist = length(p);
    float _BoundsRadius = (14. + 3. * (gBossIfsOffsetX - 1.79)) * scale;

    if (dist >= _BoundsRadius + scale) {
        opU(m, dist - _BoundsRadius, M_BOSS, 0., 0.);
        return m;
    }

    // main
    vec3 _IFS_Rot = vec3(0.09, 0.06, 0.44);

    vec4 _EyeOffset = vec4(1.7, -4.1, 3.51, 0.95);
    float _IFS_Scale = 1.36;

    float d1 = 100.0;
    float d2 = 100.0;
    float d3 = 100.0;

    p /= scale;
    p -= _IFS_Offset;
    float s = 1.;

    for (int i = ZERO; i < _IFS_Iteration; i++) {
        p = abs(p + _IFS_Offset.xyz) - _IFS_Offset.xyz;
        rot(p.xz, TAU * _IFS_Rot.x);
        rot(p.zy, TAU * _IFS_Rot.y);
        rot(p.xy, TAU * _IFS_Rot.z + 0.05 * sin(beatTau / 4. * gBossWingSpeed));
        p *= _IFS_Scale;
        s *= _IFS_Scale;

        d1 = opSmoothUnion(d1, sdBox(p, vec3(0.5, 2, 0.5)) / s - 0.3, 1.);
        d2 = opSmoothUnion(d2, sdBox(p, vec3(0.55, 2.1, 0.1)) / s - 0.3, 1.);
        if (i <= 0) d3 = min(d3, (length(p - _EyeOffset.xyz) - _EyeOffset.w) / s);
    }

    float emi = gBossEmissive;

    if (beat >= 150. && beat < 172.)
        emi *= saturate(cos(beatTau * gBossWingSpeed * 0.5 + 100.0 * length(pos)));
    else if (beat >= 200. && beat < 312.)
        emi *= saturate(cos(-beatTau * gBossWingSpeed * 0.5 + 100.0 * length(pos)));

    opU(m, d1 * scale, M_BOSS, 0., 0.);
    opU(m, d2 * scale, M_BOSS, emi, 0.);
    opU(m, d3 * scale, M_BOSS_EYE, 0., 0.);

    return m;
}

vec4 mFighter(vec3 pos, vec4 m) {
    vec3 p = pos;
    float scale = 0.001;

    // bounds sphere
    float dist = length(p);
    float _BoundsRadius = 4.5 * scale;

    if (dist >= _BoundsRadius + scale) {
        opU(m, dist - _BoundsRadius, M_FIGHTER, 0., 0.);
        return m;
    }

    // main
    vec3 _IFS_Rot = vec3(0.38, 0.55, 0.66);
    vec3 _IFS_Offset = vec3(2, 0.65, 1.38);

    p /= scale;
    p -= _IFS_Offset;

    for (int i = ZERO; i < 2; i++) {
        p = abs(p + _IFS_Offset.xyz) - _IFS_Offset.xyz;
        rot(p.xz, TAU * _IFS_Rot.x);
        rot(p.zy, TAU * _IFS_Rot.y);
        rot(p.xy, TAU * _IFS_Rot.z);
    }

    float d1 = sdBox(p, vec3(0.5, 2, 0.5)) * scale;
    float d2 = sdBox(p, vec3(0.6, 2.1, 0.1)) * scale;

    opU(m, d1, M_FIGHTER, 0., 0.);
    opU(m, d2, M_FIGHTER, 1., saturate(cos(beatTau + 1000.0 * pos.z)));

    return m;
}

float explosion_displace;

vec4 mExplosion(vec3 p, vec4 m, float scale, float time, float mz) {
    // bounds sphere
    float d = length(p) - sin(TAU * 0.5 * time) * scale;
    explosion_displace = 0.;

    if (d < 0.1 * scale) {
        explosion_displace = fbm(p / scale * 2. + time, 5);
        d += scale * explosion_displace;
    }

    opU(m, d, M_EXPLOSION, mz, 0.);

    return m;
}

uniform vec3 gDoorParam;  // 0.31 0.95 0.2

vec4 map(vec3 pos) {
    vec4 m = vec4(999., 0., 0., 0.);
    vec3 p = pos;

    // ステージ
    if (scene_id == 0) {
        p.y += 3.55;
        float d = dMandelBox(p, 4.76, 0.8, 4.0, vec3(0.7, 0.78, 0.9), vec3(0.8, 0.7, 0.5), vec3(0.3, 0.15, 0.2));

        // 球体で切り取り
        p = pos;
        p.y -= 3.;
        d = max(d, length(p) - 4.9);

        // モニュメント部分を切り取り
        float w = 0.17, h = 0.8;
        d = max(d, -sdBox(pos, vec3(w, h, w)));
        opU(m, d, M_CITY, 0., 0.);

        p = pos;
        p.y += 0.01;
        p.x = abs(p.x);
        p.x -= mix(0.51 * w, w * 1.48, easeInOutCubic(remapFrom(beat, 184., 192.0)));
        d = sdBox(p, vec3(0.5 * w, 0.01, w));
        float a = 0.;
        if (d < 0.1) {
            vec3 param = gDoorParam;
            vec2 p1 = p.xz * 20. - param.xy;
            for (int i = 0; i < 5; i++) {
                p1 = abs(p1 + param.xy) - param.xy;
                rot(p1, TAU * param.z);
            }

            float d1 = sdBox(p1, vec2(.4, .01));
            a = step(d1, 0.1);
            d += 0.003 * smoothstep(0., 0.1, d1);
        }
        opU(m, d, M_GUARDIAN, a, 0.);
    } else if (scene_id == 1) {
        float d = dLava(p);
        float s = 4.;
        d = opSmoothUnion(d, dCave(p / s) * s, 1.1);
        opU(m, d, M_LAVA, 0., 0.);
    }

    // ボス
    if (beat >= 36. && beat < 328. || beat >= 360.) {
        p = pos - boss_pos;
        if (beat < 360.) p.y -= 0.01 * sin(beatTau / 8.);
        m = mBoss(p, m);
    }

    // 戦闘機の群れ
    if (beat >= 76. && beat < 112.) {
        vec3 fighter_group_pos = vec3(gFighterGroupPosX, gFighterGroupPosY, gFighterGroupPosZ);
        p = pos - fighter_group_pos;

        if (beat >= 92.) {
            float a = 0.06;
            vec3 grid = floor(p / a + 0.5);
            p = opRepLim(p, a, vec3(7, 1, 4));
            vec2 rnd = hash23(grid);
            p.y -= 0.005 * sin(TAU * rnd.x + beatTau / 32.);
        }

        m = mFighter(p, m);
    }

    // ボスの周囲を飛び回る戦闘機
    if (beat >= 112. && beat < 184.) {
        p = pos - boss_pos;
        rot(p.xz, beatTau / 64.);
        float id;
        p.xz = pmod(p.xz, 10., id);

        bool isMany = beat >= 128.;

        vec3 p1 = p;
        p1.z -= 0.1;
        float a = 0.04;
        float id1 = floor(p1.y / a + 0.5);
        float rnd = hash11(id + id1);
        if (isMany) p1.y = opRepLim(p1.y, a, 1.);
        if (beat < 170.) m = mExplosion(p1, m, 0.02, saturate(mod(rnd * 4. + beat * 0.5, 4.)), 0.8);

        p.z -= 0.2 + remapFrom(beat, 168., 180.);
        if (isMany) p.yz = opRepLim(p.yz, 0.1, vec2(1, 2));

        // ビームで全滅
        float time = saturate((beat - remapTo(rnd, 172., 175.)) / 3.);
        if (time < 0.99) m = mExplosion(p, m, 0.008, time, 0.0);
        if (time < 0.9) m = mFighter(p, m);
    }

    // ガーディアン
    if (beat >= 184.) {
        p = pos - gurdian_pos;
        m = mGuardian(p, m);
    }

    return m;
}

// https://iquilezles.org/articles/normalsSDF
vec3 calcNormal(vec3 pos, float eps) {
#if 0
    vec2 e = vec2(1.0, -1.0) * 0.5773 * eps;
    return normalize(e.xyy * map(pos + e.xyy).x + e.yyx * map(pos + e.yyx).x + e.yxy * map(pos + e.yxy).x + e.xxx * map(pos + e.xxx).x);
#else
    // inspired by tdhooper and klems - a way to prevent the compiler from inlining map() 4 times
    vec3 n = vec3(0.0);
    for (int i = ZERO; i < 4; i++) {
        vec3 e = 0.5773 * (2.0 * vec3((((i + 3) >> 1) & 1), ((i >> 1) & 1), (i & 1)) - 1.0);
        n += e * map(pos + eps * e).x;
        // if (n.x + n.y + n.z > 100.0) break;
    }
    return normalize(n);
#endif
}

// https://iquilezles.org/articles/rmshadows
float calcSoftshadow(vec3 ro, vec3 rd, float mint, float tmax) {
    // bounding volume
    float tp = (0.8 - ro.y) / rd.y;
    if (tp > 0.0) tmax = min(tmax, tp);

    float res = 1.0;
    float t = mint;
    for (int i = ZERO; i < 24; i++) {
        float h = map(ro + rd * t).x;
        float s = saturate(8.0 * h / t);
        res = min(res, s);
        t += clamp(h, 0.01, 0.2);
        if (res < 0.004 || t > tmax) break;
    }
    res = saturate(res);
    return res * res * (3.0 - 2.0 * res);
}

// https://iquilezles.org/articles/nvscene2008/rwwtt.pdf
float calcAO(vec3 pos, vec3 nor) {
    float occ = 0.0;
    float sca = 1.0;
    for (int i = ZERO; i < 5; i++) {
        float h = 0.01 + 0.12 * float(i) / 4.0;
        float d = map(pos + h * nor).x;
        occ += (h - d) * sca;
        sca *= 0.95;
        if (occ > 0.35) break;
    }
    return clamp(1.0 - 3.0 * occ, 0.0, 1.0) * (0.5 + 0.5 * nor.y);
}

vec3 F_fresnelSchlick(vec3 F0, float cosTheta) { return F0 + (1.0 - F0) * pow(1.0 - cosTheta, 5.0); }

float D_GGX(float NdotH, float roughness) {
    float alpha = roughness * roughness;
    float alphaSq = alpha * alpha;
    float denom = (NdotH * NdotH) * (alphaSq - 1.0) + 1.0;
    return alphaSq / (PI * denom * denom);
}

float schlickG1(float cosTheta, float k) { return cosTheta / (cosTheta * (1.0 - k) + k); }

float G_schlickGGX(float NdotL, float NdotV, float roughness) {
    float r = roughness + 1.0;
    float k = (r * r) / 8.0;
    return schlickG1(NdotL, k) * schlickG1(NdotV, k);
}

// https://www.shadertoy.com/view/WlffWB
vec3 directLighting(vec3 pos, vec3 albedo, float metalness, float roughness, vec3 N, vec3 V, vec3 L, vec3 lightColor) {
    vec3 H = normalize(L + V);
    float NdotV = max(0.0, dot(N, V));
    float NdotL = max(0.0, dot(N, L));
    float NdotH = max(0.0, dot(N, H));
    float HdotL = max(0.0, dot(H, L));

    vec3 F0 = mix(vec3(0.04), albedo, metalness);

    vec3 F = F_fresnelSchlick(F0, HdotL);
    float D = D_GGX(NdotH, roughness);
    float G = G_schlickGGX(NdotL, NdotV, roughness);
    vec3 specularBRDF = (F * D * G) / max(0.0001, 4.0 * NdotL * NdotV);

    vec3 kd = mix(vec3(1.0) - F, vec3(0.0), metalness);
    vec3 diffuseBRDF = kd * albedo / PI;

    float shadow = calcSoftshadow(pos + N * 0.1, L, 0.1, 5.);
    vec3 irradiance = lightColor * NdotL * shadow;

    return (diffuseBRDF + specularBRDF) * irradiance;
}

vec3 ambientLighting(vec3 pos, vec3 albedo, float metalness, float roughness, vec3 N, inout vec3 reflection) {
    float ao = calcAO(pos, N);
    float ambientReflection = step(0.95, metalness) * step(roughness, 0.05);
    reflection *= albedo * ambientReflection;
    return albedo * (1.0 - ambientReflection) * mix(skyColor(N), vec3(1), 0.7) * ao;
}

uniform float gMetalness;  // 0.5 0 1
uniform float gRoughness;  // 0.5 0 1

float inRange(float t, float a, float b) { return a <= t && t < b ? 1.0 : 0.0; }

uniform float gRiberMin;             // 0.5 0 3
uniform float gGreenNoiseIntensity;  // 1 0 2
uniform float gGreenNoiseFreq;       // 500 0 1000

uniform float gRaymarchingEps; // 0.0003

vec3 raymarch(inout vec3 ro, inout vec3 rd, vec3 bgcol, inout bool hit, inout vec3 reflection) {
    vec3 col = vec3(0);
    vec3 p;
    vec4 m;
    depth = 0.;
    float eps;

    for (int i = ZERO; i < 200; i++) {
        p = ro + rd * depth;
        m = map(p);
        depth += m.x;
        eps = depth * gRaymarchingEps;
        if (m.x < eps) {
            break;
        }
    }

    float range = scene_id == 0 ? 4.5 : 30.;

    if (sdBox(p, vec3(range)) < 0.) {
        vec3 N = calcNormal(p, eps);

        vec3 albedo = vec3(1, 1, 1);
        vec3 emissive = vec3(0.);
        float metalness = gMetalness;
        float roughness = gRoughness;

        if (m.y == M_CITY) {
            if (p.y >= 0.0) {
                if (dot(N, vec3(0, 1, 0)) > 0.5 && p.y <= 0.05) {
                    // ground
                    float noise = gGreenNoiseIntensity * (fbm(p * gGreenNoiseFreq, 5) - 0.5);
                    float green = inRange(orbitTrap.x, gRiberMin + noise - 0.3, gRiberMin + noise + 0.6);
                    albedo = mix(vec3(222, 184, 135) / 255., vec3(0.2, 0.3, 0.2), green);
                    metalness = mix(0.0, 0.1, green);
                    roughness = mix(0.9, 0.9, green);

                    float riber = inRange(orbitTrap.x, gRiberMin, gRiberMin + 0.2);
                    albedo = mix(albedo, vec3(0.7, 0.8, 1.0), riber);
                    metalness = mix(metalness, 1.0, riber);
                    roughness = mix(roughness, 0.0, riber);
                    N = mix(N, vec3(0, 1, 0), riber);
                } else if (p.y >= 0.01) {
                    // buildings
                    vec3 span = vec3(0.005, 0.002, 0.005);
                    if (beat >= 8. && beat < 348.) span /= 4.;
                    vec3 grid = floor(p / span);
                    grid = mod(grid, vec3(4, 4, 4));
                    float glass = step(0.5, grid.x) * step(0.5, grid.y) * step(0.5, grid.z);

                    if (glass > 0.1) {
                        albedo = vec3(0.1, 0.1, 0.3);
                        metalness = 0.8;
                        roughness = 0.1;
                    } else {
                        albedo = vec3(1.0);
                        metalness = 0.3;
                        roughness = 0.9;
                    }
                }
            }
        } else if (m.y == M_GUARDIAN) {
            metalness = 0.1;
            roughness = 0.7;
            albedo = vec3(1.);

            if (m.z == 1.) {
                metalness = 1.;
                roughness = 0.;
                albedo = vec3(1.0, 0.85, 0.1);
                emissive = vec3(0.1, 0.1, 1) * m.w;
            } else if (m.z == 2.) {
                // ring
                emissive = vec3(1.0, 1.0, 0.6) * 2.;
            }
        } else if (m.y == M_FIGHTER) {
            metalness = 0.1;
            roughness = 0.7;
            albedo = mix(vec3(0.6), vec3(0.1), m.z);
            emissive = vec3(0.1, 0.3, 1.0) * m.w * 3.;
        } else if (m.y == M_LAVA) {
            metalness = 0.6;
            roughness = 0.6;
            albedo = vec3(0.6);
            emissive = vec3(255, 79, 1) / 255. * 2.0 * step(p.y, mix(-0.02, 0.05, saturate((beat - 52.) / 24.)));
        } else if (m.y == M_BOSS) {
            metalness = 0.3;
            roughness = 0.7;
            albedo = vec3(0.3, 0.3, 0.3);
            emissive = vec3(255, 79, 1) / 255. * m.z;
        } else if (m.y == M_BOSS_EYE) {
            metalness = 1.;
            roughness = 0.;
            albedo = vec3(255, 79, 1) / 255.;
            emissive = vec3(255, 79, 1) / 255. * 0.1;
        } else if (m.y == M_EXPLOSION) {
            vec3 c0 = mix(vec3(3), vec3(0.3, 0.3, 3), m.z);
            vec3 c1 = vec3(1, 1, 0.1);
            vec3 c2 = vec3(1, 0.1, 0.1);
            vec3 c3 = vec3(0.4);

            float t = fract(explosion_displace * 3.);
            if (explosion_displace < 0.3333) {
                albedo = mix(c0, c1, t);
            } else if (explosion_displace < 0.6666) {
                albedo = mix(c1, c2, t);
            } else {
                albedo = mix(c2, c3, t);
            }

            emissive = albedo * 2.;
        }

        vec3 lightDir = sundir;
        float lightAttenuation = 1.0;

        if (scene_id == 1) {
            vec3 lightVec = vec3(0, 3, 0) - p;
            lightDir = normalize(lightVec);
            // lightAttenuation /= dot(lightVec, lightVec);
        }

        col += directLighting(p, albedo, metalness, roughness, N, -rd, lightDir, lightColorDirectional) * lightAttenuation;

        if (beat >= 184.) {
            vec3 q = gurdian_pos + vec3(0, 0.22, 0) - p;
            float d = length(q);
            vec3 ldir = normalize(q);
            col += directLighting(p, albedo, metalness, roughness, N, -rd, ldir, mix(0.02, 0.03, 0.5 + 0.5 * cos(beatTau / 8.)) * vec3(1.0, 1.0, 0.6)) / (d * d);
        }

        if (beat >= 264. && beat < 328.) {
            vec3 q = gurdian_pos + vec3(0, 0.12, gGuardianChargePosZ) - p;
            float d = length(q) - gGuardianChargeRadius;
            vec3 ldir = normalize(q);
            col += directLighting(p, albedo, metalness, roughness, N, -rd, ldir, 0.5 * gGuardianChargeBrightness * vec3(0.1, 0.1, 1)) / (d * d);
        }

        col += ambientLighting(p, albedo, metalness, roughness, N, reflection) * lightColorAmbient;
        col += emissive;
        hit = true;
        ro = p + 0.05 * N;
        rd = reflect(rd, N);
    } else {
        col = bgcol;
        hit = false;
    }

    return col;
}

vec3 renderScene(inout vec3 ro, inout vec3 rd, vec2 px, inout bool hit, inout vec3 reflection) {
    // original ray
    vec3 ro0 = ro;
    vec3 rd0 = rd;

    // sky
    vec3 bgcol = skyColor(rd0);

    // opaque geometory
    vec3 col = raymarch(ro, rd, bgcol, hit, reflection);

    return col;
}

float depth_primary = 0.0;

vec3 render(vec3 ro, vec3 rd, vec2 px) {
    bool hit = false;
    vec3 reflection = vec3(1);
    vec3 col = vec3(0);

    for (int i = ZERO; i < 2; i++) {
        col += reflection * renderScene(ro, rd, px, hit, reflection);
        if (i == 0) depth_primary = depth;
        if (!hit || dot(reflection, reflection) < 0.01) break;
    }

    return col;
}

uniform float gMotionBlur;  // 0.3 0 1

void mainImage(out vec4 fragColor, vec2 fragCoord) {
    beat = gBeat;
    beatTau = beat * TAU;
    beatPhase = phase(beat / 2.);

    vec2 uv = fragCoord.xy / iResolution.xy;

    // Camera
    vec2 noise = hash23(vec3(iFrame, fragCoord)) - .5;  // AA
    // noise *= 0.;
    vec2 uv2 = (2. * (fragCoord.xy + noise) - iResolution.xy) / iResolution.x;

    scene_id = 0;

    if (beat >= 35. && beat < 60.) {
        scene_id = 1;
        lightColorDirectional = vec3(255, 79, 1) / 255. * 3.;
        lightColorAmbient = vec3(255, 79, 1) / 255. * 0.1;
    }

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

    vec3 scol = clamp(render(ro, rd, fragCoord), 0.0, 100.0);
    vec3 bufa = texture(iChannel0, uv).xyz;
    scol = mix(scol, bufa, gMotionBlur);
    fragColor = vec4(scol, depth_primary);
}
