// Kitchen programs (RealityHD 6): running-bond subway tile, engineered oak plank floor, gas flame
// crown, engineered quartz slab.

let metalKitchen = #"""
// ---------------------------------------------------------------- kitchen
// Glazed subway tile in running bond: pillowed edges, glaze ripple, recessed grout.
// colorA glaze, colorB grout, colorC grime (a = amount). f.x tiles along u per repeat, f.y rows along v
// (even), f.z grout width (uv units), f.w per-tile tone variation.
S subwayTile(float2 uv, constant RFParams &P) {
    S s = defaults(); uint sd = P.seed;
    float2 n = float2(max(1.0, floor(P.f.x + 0.5)), max(2.0, floor(P.f.y * 0.5 + 0.5) * 2.0));
    float2 g = uv * n;
    float row = floor(g.y);
    g.x += fmod(row, 2.0) > 0.5 ? 0.5 : 0.0;
    float2 gi = floor(g); float2 gf = g - gi;
    int2 id = wrapc(int2(gi), int2(n));
    float dx = min(gf.x, 1.0 - gf.x) / n.x, dy = min(gf.y, 1.0 - gf.y) / n.y;
    float d = min(dx, dy);
    float gw = P.f.z * 0.5;
    float grout = 1.0 - smoothstep(gw * 0.85, gw * 1.15, d);
    // Rounded cushion edge about 2.5 grout widths wide.
    float e = sat((d - gw) / (gw * 2.5));
    float cushion = sqrt(e * (2.0 - e));
    float tv = h01(id, sd + 3u);
    float ripple = fbm(uv, int2(int(n.x) * 3, int(n.y) * 2), 3, sd + 5u);
    float pin = smoothstep(0.42, 0.5, fbm(uv, int2(int(n.x) * 40, int(n.y) * 20), 2, sd + 11u)) * 0.6;
    float3 glaze = P.colorA.rgb * (1.0 + (tv - 0.5) * P.f.w) * (0.985 + 0.03 * ripple);
    glaze = mix(glaze, glaze * 0.93, (1.0 - cushion) * 0.5);
    float3 gr = P.colorB.rgb * (0.88 + 0.24 * fbm(uv, int2(160, 160), 2, sd + 7u));
    float grime = P.colorC.a * smoothstep(-0.1, 0.5, fbm(uv, int2(4, 4), 3, sd + 9u));
    gr = mix(gr, P.colorC.rgb, grime);
    s.albedo = mix(glaze, gr, grout);
    s.height = mix(0.42 + 0.16 * cushion + ripple * 0.03 - pin * 0.01, 0.3, grout);
    s.rough = mix(0.06 + 0.04 * (ripple + 0.5) + pin * 0.1, 0.9, grout);
    s.ao = 1.0 - grout * 0.4 - (1.0 - cushion) * 0.08;
    s.metal = 0.0;
    return s;
}

// Engineered oak plank floor: boards along u, f.x boards across v per repeat, each row split into
// 1-3 boards with a random stagger; per-board tone, flat-sawn figure, pores, micro-bevel seams, satin
// lacquer with fine scuffs. colorA light wood, colorB dark grain, colorC seam shadow.
// f.y roughness, f.z board tone variation, f.w bevel width (uv units).
S plankFloor(float2 uv, constant RFParams &P) {
    S s = defaults(); uint sd = P.seed;
    int R = max(1, int(P.f.x + 0.5));
    float gy = uv.y * float(R); float ri = floor(gy); float fy = gy - ri;
    int r = ((int(ri) % R) + R) % R;
    float nb = 1.0 + floor(h01(int2(r, 1), sd) * 2.999);
    float off = h01(int2(r, 2), sd);
    float gx = (uv.x + off) * nb; float bi = floor(gx); float fx = gx - bi;
    int b = ((int(bi) % int(nb)) + int(nb)) % int(nb);
    float bh = h01(int2(b, r), sd + 17u), bh2 = h01(int2(b, r), sd + 23u);
    // Figure: board-local grain lines (about 4 mm apart at a 2 m repeat) bent into arches.
    float2 q = float2(uv.x, uv.y + bh * 0.37);
    float warp = fbm(q, int2(2, 24), 4, sd + 1u) * 1.0 + fbm(q, int2(6, 60), 2, sd + 2u) * 0.15;
    float figure = q.y * 480.0 + warp * 28.0 + sin((uv.x + bh2) * 6.2831853 * nb) * 3.0 * bh2;
    float rr = fract(figure);
    float late = smoothstep(0.0, 0.1, rr) * (1.0 - smoothstep(0.1, 0.5, rr));
    float streak = fbm(q, int2(8, 400), 3, sd + 4u);
    float pores = smoothstep(0.3, 0.6, fbm(q, int2(40, 1200), 1, sd + 9u));
    float ray = smoothstep(0.62, 0.7, fbm(q, int2(60, 300), 2, sd + 12u)) * 0.5;
    float tone = (bh - 0.5) * P.f.z;
    float3 c = mix(P.colorA.rgb, P.colorB.rgb, sat(0.3 + streak * 0.6 + late * 0.45 - tone));
    c *= 1.0 + tone * 0.6;
    c *= 1.0 - pores * 0.08;
    c = mix(c, c * 1.12, ray);
    // Bevel seams: long edges and butt ends.
    float ey = min(fy, 1.0 - fy) / float(R), ex = min(fx, 1.0 - fx) / nb;
    float ed = min(ex, ey);
    float bev = 1.0 - smoothstep(0.0, P.f.w, ed);
    float gap = 1.0 - smoothstep(0.0, P.f.w * 0.25, ed);
    c = mix(c, P.colorC.rgb, gap * 0.85);
    c = mix(c, c * 0.8, bev * 0.4);
    // Traffic: fine scuffs and lacquer haze.
    float scuff = smoothstep(0.55, 0.7, fbm(uv * float2(1, 1), int2(200, 30), 2, sd + 31u)) * smoothstep(-0.1, 0.4, fbm(uv, int2(3, 3), 3, sd + 33u));
    c = mix(c, c * 1.08 + float3(0.01), scuff * 0.3);
    s.albedo = c;
    s.height = 0.5 - bev * 0.25 - gap * 0.1 - late * 0.01 - pores * 0.02 + streak * 0.01;
    s.rough = sat(P.f.y + pores * 0.1 + bev * 0.15 + scuff * 0.12 + late * 0.02);
    s.ao = 1.0 - gap * 0.5 - bev * 0.15;
    s.metal = 0.0;
    return s;
}

// Gas burner flame crown (atlas: u around the burner, 0..1; v from port to tip, 0..1). f.x tongues
// per revolution, f.y tongue length variation, f.z orange tip amount, f.w inner cone length.
// colorA inner cone, colorB outer mantle, colorC tip. Alpha shapes the tongues.
S gasFlame(float2 uv, constant RFParams &P) {
    S s = defaults(); uint sd = P.seed;
    float N = max(1.0, floor(P.f.x + 0.5));
    float k = floor(uv.x * N);
    float u = fract(uv.x * N) - 0.5;
    float j = h01(int2(int(k), 0), sd), j2 = h01(int2(int(k), 1), sd);
    float len = 1.0 - P.f.y * j;
    float t = sat(uv.y / len);
    float flick = fbm(float2(uv.x, uv.y * 0.5), int2(int(N) * 2, 2), 2, sd + 5u) * 0.12;
    float w = 0.46 * pow(max(0.0, 1.0 - t), 0.55) * (0.55 + 0.45 * smoothstep(0.0, 0.12, t));
    float uu = abs(u + flick * t);
    float mantle = (1.0 - smoothstep(w * 0.55, w, uu)) * (1.0 - smoothstep(0.85, 1.0, t)) * step(uv.y, len);
    float cl = P.f.w;
    float wc = 0.3 * max(0.0, 1.0 - t / cl) * smoothstep(0.0, 0.06, t);
    float core = 1.0 - smoothstep(wc * 0.45, wc + 0.02, uu);
    core *= step(t, cl);
    float tip = smoothstep(0.55, 0.95, t) * P.f.z * step(0.55, j2);
    float3 col = P.colorB.rgb * (0.55 + 0.45 * (1.0 - t));
    col = mix(col, P.colorA.rgb, core);
    col = mix(col, P.colorC.rgb, tip);
    s.albedo = col;
    s.alpha = sat(mantle * (0.55 + 0.45 * core) + core * 0.4) * (1.0 - smoothstep(0.92, 1.0, uv.y));
    s.alpha = max(s.alpha, tip * mantle * 0.6);
    s.height = 0.5; s.rough = 1.0; s.ao = 1.0; s.metal = 0.0;
    return s;
}

// Engineered quartz: near-uniform ground with fine quartz-grain speckle (0.5-2 mm), sparse glassy
// flecks and soft low-contrast veins. colorA ground, colorB vein (a = vein amount), colorC speckle
// (a = speckle amount). f.x speckle cells per repeat, f.y vein warp, f.z vein width, f.w roughness.
S quartzSlab(float2 uv, constant RFParams &P) {
    S s = defaults(); uint sd = P.seed;
    int F = max(16, int(P.f.x + 0.5));
    float4 w1 = worley(uv, int2(F, F), sd + 1u, 1.0);
    float4 w2 = worley(uv, int2(F * 2, F * 2), sd + 2u, 1.0);
    float grain1 = (1.0 - smoothstep(0.18, 0.32, w1.x)) * step(0.55, w1.z);
    float grain2 = (1.0 - smoothstep(0.15, 0.3, w2.x)) * step(0.7, w2.z);
    float glassy = (1.0 - smoothstep(0.1, 0.22, w1.x)) * step(0.93, w1.w);
    float cloud = fbm(uv, int2(3, 3), 5, sd + 3u);
    float2 p = uv + float2(fbm(uv, int2(2, 2), 4, sd + 4u), fbm(uv, int2(2, 2), 4, sd + 5u)) * P.f.y;
    float vn = fbm(p, int2(2, 2), 5, sd + 6u) + sin(6.2831853 * (p.x * 2.0 + p.y)) * 0.15;
    float vein = (1.0 - smoothstep(P.f.z * 0.3, P.f.z, abs(vn))) * smoothstep(-0.1, 0.3, fbm(uv, int2(3, 3), 3, sd + 7u));
    float3 c = P.colorA.rgb * (0.985 + cloud * 0.04);
    c = mix(c, P.colorC.rgb, sat(grain1 * 0.8 + grain2 * 0.5) * P.colorC.a);
    c = mix(c, P.colorB.rgb, vein * P.colorB.a);
    c = mix(c, c * 1.06 + float3(0.02), glassy);
    // Fine use scratches: thin straight hairlines in three directions, patchy.
    float scr = 0.0;
    for (int i = 0; i < 3; i++) {
        float a = h01u(sd + uint(i) * 17u) * 3.14159;
        int2 fr = int2(3 * (i + 2), 700);
        float2 r = rot2(uv - 0.5, a) + 0.5;
        float sn = gnoise(fract(r) * float2(fr), fr, sd + 40u + uint(i));
        scr = max(scr, (1.0 - smoothstep(0.0, 0.035, abs(sn))) * smoothstep(0.15, 0.45, fbm(uv, int2(4, 4), 3, sd + 50u + uint(i))));
    }
    c = mix(c, c * 1.04 + float3(0.015), scr * 0.5);
    s.albedo = c;
    s.height = 0.5 + glassy * 0.01 - scr * 0.01;
    s.rough = sat(P.f.w - glassy * 0.06 + grain1 * 0.02 + scr * 0.22);
    s.ao = 1.0; s.metal = 0.0;
    return s;
}
"""#
