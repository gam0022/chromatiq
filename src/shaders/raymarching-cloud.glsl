vec4 prevColor;

uniform float gCloudHeight;  // -0.4 -2 2
uniform float gCloudSpeed; // 0.25

float mapCloud(vec3 p, int oct) {
    vec3 q = p + iTime * gCloudSpeed;
    float g = 0.5 + 0.5 * noise(q * 0.3);

    float f = fbm(q, oct);
    f = mix(f * 0.1 - 0.5, f, g * g);

    return 1.5 * f - p.y + gCloudHeight;
}

// Clouds
// https://www.shadertoy.com/view/XslGRr
vec4 raymarchCloud(vec3 ro, vec3 rd, vec3 bgcol, vec2 px) {
    const int kDiv = 1;  // make bigger for higher quality

    // bounding planes
    float yb = gCloudHeight - 2.;
    float yt = gCloudHeight + 1.;
    float tb = (yb - ro.y) / rd.y;
    float tt = (yt - ro.y) / rd.t;

    // find tigthest possible raymarching segment
    float tmin, tmax;
    if (ro.y > yt) {
        // above top plane
        if (tt < 0.0) return vec4(0.0);  // early exit
        tmin = tt;
        tmax = tb;
    } else {
        // inside clouds slabs
        tmin = 0.0;
        tmax = 60.0;
        if (tt > 0.0) tmax = min(tmax, tt);
        if (tb > 0.0) tmax = min(tmax, tb);
    }

    // 不透明と合成
    tmax = min(tmax, prevColor.a);

    // dithered near distance
    float t = tmin + 0.1 * hash12(px);

    // raymarch loop
    vec4 sum = vec4(0.0);
    for (int i = ZERO; i < 190 * kDiv; i++) {
        // step size
        float dt = max(0.05, 0.02 * t / float(kDiv));

        int oct = 5 - int(log2(1.0 + t * 0.5));

        // sample cloud
        vec3 pos = ro + t * rd;
        float den = mapCloud(pos, oct);
        if (den > 0.01)  // if inside
        {
            // do lighting
            float dif = clamp((den - mapCloud(pos + 0.3 * sundir, oct)) / 0.25, 0.0, 1.0);
            vec3 lin = vec3(0.65, 0.65, 0.75) * 1.1 + 0.8 * vec3(0.6, 0.6, 0.5) * dif;
            vec4 col = vec4(mix(vec3(1.0), vec3(0.25, 0.3, 0.4), den), den);
            col.xyz *= lin;
            // fog
            col.xyz = mix(col.xyz, bgcol, 1.0 - exp2(-0.1 * t));
            // composite front to back
            col.w = min(col.w * 8.0 * dt, 1.0);
            col.rgb *= col.a;
            sum += col * (1.0 - sum.a);
        }
        // advance ray
        t += dt;
        // until far clip or full opacity
        if (t > tmax || sum.a > 0.99) break;
    }

    return clamp(sum, 0.0, 1.0);
}

vec3 renderScene(inout vec3 ro, inout vec3 rd, vec2 px) {
    // sky
    vec3 bgcol = skyColor(rd);

    // opaque geometory
    vec3 col = prevColor.rgb;

    if (scene_id == 0) {
        // clouds
        vec4 res = raymarchCloud(ro, rd, bgcol, px);
        col = col * (1.0 - res.w) + res.xyz;

        // sun glare
        float sun = sunColor(rd);
        col += 0.2 * vec3(1.0, 0.4, 0.2) * pow(sun, 3.0);
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
    vec2 noise = hash23(vec3(iFrame, fragCoord)) - .5;  // AA
    vec2 uv2 = (2. * (fragCoord.xy + noise) - iResolution.xy) / iResolution.x;

    scene_id = 0;

    if (beat >= 35. && beat < 60.) {
        scene_id = 1;
    }

    ro = vec3(gCameraEyeX, gCameraEyeY, gCameraEyeZ);
    target = vec3(gCameraTargetX, gCameraTargetY, gCameraTargetZ);
    fov = gCameraFov;

    vec3 up = vec3(0, 1, 0);
    vec3 fwd = normalize(target - ro);
    vec3 right = normalize(cross(up, fwd));
    up = normalize(cross(fwd, right));
    vec3 rd = normalize(right * uv2.x + up * uv2.y + fwd / tan(fov * TAU / 720.));

    vec3 scol = clamp(renderScene(ro, rd, fragCoord), 0.0, 100.0);
    fragColor = vec4(scol, 1);
}