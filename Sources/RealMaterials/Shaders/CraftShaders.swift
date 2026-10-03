// RealityHD 3 craft programs: leather, brushedMetal, polishedMetal, ceramicGlaze, caneWeave.

let metalCraft = #"""
// ---------------------------------------------------------------- craft / interior
// Full-grain leather: pebble grain cells, creases, rubbed wear, mottled dye.
// colorA dye, colorB crease/pore dark, colorC rubbed highlight. f.x grain cells per tile,
// f.y wear (rubbed patches + scuffs), f.z base roughness, f.w crease amount.
S leather(float2 uv, constant RFParams &P) {
    S s = defaults(); uint sd = P.seed;
    int g = int(max(8.0, P.f.x));
    float2 wuv = uv + float2(fbm(uv, int2(4, 4), 2, sd + 1u), fbm(uv, int2(4, 4), 2, sd + 2u)) * 0.012;
    float4 c1 = worley(fract(wuv), int2(g, g), sd + 3u, 0.95);
    float4 c2 = worley(fract(wuv), int2(g * 3, g * 3), sd + 4u, 0.95);
    float groove = 1.0 - smoothstep(0.0, 0.12, c1.y - c1.x);
    float fine = 1.0 - smoothstep(0.0, 0.1, c2.y - c2.x);
    float bump = sqrt(sat(1.0 - c1.x * 1.1)) * 0.6 + sqrt(sat(1.0 - c2.x)) * 0.25;
    float crease = 0.0;
    for (int i = 0; i < 2; i++) {
        float r = ridged(uv, int2(3 + i * 2, 2 + i), 4, sd + 10u + uint(i));
        crease = max(crease, smoothstep(0.72, 0.95, r));
    }
    crease *= P.f.w;
    float mott = fbm(uv, int2(3, 3), 5, sd + 5u);
    float rub = smoothstep(0.05, 0.45, fbm(uv, int2(2, 2), 4, sd + 6u) + (P.f.y - 0.5) * 0.6) * P.f.y;
    float scuff = 0.0;
    for (int i = 0; i < 3; i++) {
        float a = h01u(sd + uint(i) * 17u) * 3.14159;
        int2 fr = int2(5 + i * 3, 90);
        float2 r = rot2(uv - 0.5, a) + 0.5;
        float n = gnoise(fract(r) * float2(fr), fr, sd + 30u + uint(i));
        scuff = max(scuff, (1.0 - smoothstep(0.0, 0.035, abs(n))) * smoothstep(0.25, 0.6, fbm(uv, int2(4, 4), 3, sd + 40u + uint(i))));
    }
    scuff *= P.f.y;
    float3 c = P.colorA.rgb * (0.88 + 0.24 * (mott + 0.5));
    c = mix(c, P.colorB.rgb, sat(groove * 0.55 + fine * 0.2 + crease * 0.7));
    c = mix(c, P.colorC.rgb, sat(rub * 0.55 + scuff * 0.6) * (1.0 - groove * 0.7));
    s.albedo = c;
    s.height = 0.5 + bump * 0.18 - groove * 0.12 - fine * 0.04 - crease * 0.25 - scuff * 0.03;
    s.rough = sat(P.f.z + groove * 0.12 + fine * 0.05 + crease * 0.1 - rub * 0.15 + scuff * 0.1);
    s.ao = 1.0 - groove * 0.25 - crease * 0.35;
    s.metal = 0.0; s.alpha = 1.0;
    return s;
}

// Brushed metal (aluminum, stainless): fine streaks along U, smudges, light scratches.
// colorA metal tint, colorB smudge tint. f.x streak strength, f.y base roughness, f.z smudges, f.w scratches.
S brushedMetal(float2 uv, constant RFParams &P) {
    S s = defaults(); uint sd = P.seed;
    float st = gnoise(uv * float2(3, 900), int2(3, 900), sd + 1u) * 0.6 + gnoise(uv * float2(6, 2400), int2(6, 2400), sd + 2u) * 0.4;
    float band = fbm(uv, int2(2, 40), 3, sd + 3u);
    float smudge = smoothstep(0.05, 0.5, fbm(uv, int2(3, 3), 5, sd + 4u)) * P.f.z;
    float prints = 0.0;
    {
        float cid, cid2; float2 o = cellLocal(uv, int2(5, 5), sd + 5u, cid, cid2);
        float d = length(o / float2(0.14, 0.18));
        float ridges = 0.5 + 0.5 * sin(d * 90.0 + cid * 6.0);
        prints = (1.0 - smoothstep(0.7, 1.0, d)) * step(0.7, cid) * ridges * P.f.z;
    }
    float scratch = 0.0;
    for (int i = 0; i < 4; i++) {
        float a = h01u(sd + uint(i) * 13u) * 3.14159;
        int2 fr = int2(3 + i * 2, 220);
        float2 r = rot2(uv - 0.5, a) + 0.5;
        float n = gnoise(fract(r) * float2(fr), fr, sd + 20u + uint(i));
        scratch = max(scratch, (1.0 - smoothstep(0.0, 0.012, abs(n))) * smoothstep(0.3, 0.6, fbm(uv, int2(3, 3), 3, sd + 50u + uint(i))));
    }
    scratch *= P.f.w;
    float3 c = P.colorA.rgb * (0.94 + st * 0.08 * P.f.x + band * 0.05);
    c = mix(c, P.colorB.rgb, sat(smudge * 0.25 + prints * 0.2));
    c *= 1.0 + scratch * 0.12;
    s.albedo = c;
    s.metal = 1.0;
    s.rough = sat(P.f.y + st * 0.06 * P.f.x + smudge * 0.12 + prints * 0.15 - scratch * 0.1);
    s.height = 0.5 + st * 0.012 * P.f.x - scratch * 0.06;
    s.ao = 1.0;
    s.alpha = 1.0;
    return s;
}

// Polished or hammered brass/copper/bronze aging to tarnish and verdigris.
// colorA bright metal, colorB tarnish, colorC patina (verdigris). f.x tarnish, f.y patina,
// f.z hammer dimples per tile (0 = smooth spun), f.w base roughness.
S polishedMetal(float2 uv, constant RFParams &P) {
    S s = defaults(); uint sd = P.seed;
    float dimple = 0.0, rim = 0.0;
    if (P.f.z > 0.5) {
        int q = int(P.f.z);
        float4 w = worley(uv, int2(q, q), sd + 1u, 0.85);
        // Concave dents: height falls with distance from the cell border, continuous across borders.
        dimple = sat((w.y - w.x) * 1.6);
        rim = 1.0 - smoothstep(0.0, 0.06, w.y - w.x);
    }
    float spin = gnoise(uv * float2(2, 700), int2(2, 700), sd + 2u);
    float n = fbm(uv, int2(3, 3), 5, sd + 3u);
    float tarn = smoothstep(-0.25, 0.35, n + (P.f.x - 0.5) * 0.8) * P.f.x;
    float pn = fbm(uv, int2(4, 4), 5, sd + 4u) + 0.25 * fbm(uv, int2(16, 16), 3, sd + 5u);
    float pat = smoothstep(0.1, 0.35, pn + (P.f.y - 0.6) * 0.7) * P.f.y;
    float spots = smoothstep(0.22, 0.05, worley(uv, int2(14, 14), sd + 6u, 1.0).x) * P.f.y;
    pat = sat(pat + spots * 0.6);
    float3 metal = P.colorA.rgb * (0.95 + 0.06 * (1.0 - dimple) + spin * 0.03);
    float3 c = mix(metal, P.colorB.rgb * (0.85 + 0.3 * (n + 0.5)), tarn * 0.85);
    c = mix(c, P.colorC.rgb * (0.85 + 0.3 * pn), pat);
    s.albedo = c;
    s.metal = sat(1.0 - pat * 0.95 - tarn * 0.15);
    s.rough = sat(P.f.w + tarn * 0.25 + pat * 0.55 + rim * 0.04 + abs(spin) * 0.03);
    s.height = 0.5 - dimple * 0.1 + pat * 0.06;
    s.ao = 1.0 - pat * 0.1;
    s.alpha = 1.0;
    return s;
}

// Glazed ceramic (stoneware, porcelain, celadon): glaze color shifts and runs along V, iron
// speckle, optional crackle. colorA glaze, colorB thin/break glaze, colorC speckle.
// f.x speckle density, f.y variation and runs, f.z crackle, f.w gloss roughness.
S ceramicGlaze(float2 uv, constant RFParams &P) {
    S s = defaults(); uint sd = P.seed;
    float runs = fbm(uv, int2(28, 2), 3, sd + 1u) * 0.6 + fbm(uv, int2(10, 1), 3, sd + 2u) * 0.4;
    float pool = fbm(uv, int2(3, 3), 4, sd + 3u);
    float v = sat(0.5 + (runs * 0.8 + pool * 0.6) * P.f.y);
    float3 c = mix(P.colorB.rgb, P.colorA.rgb, smoothstep(0.25, 0.75, v));
    float4 sp = worley(uv, int2(60, 60), sd + 4u, 1.0);
    float speck = smoothstep(0.12, 0.04, sp.x) * step(1.0 - P.f.x, sp.z);
    float4 sp2 = worley(uv, int2(140, 140), sd + 5u, 1.0);
    speck = max(speck, smoothstep(0.1, 0.03, sp2.x) * step(1.0 - P.f.x * 0.7, sp2.z) * 0.7);
    float4 cr = worley(uv, int2(9, 9), sd + 6u, 0.9);
    float4 cr2 = worley(uv, int2(22, 22), sd + 7u, 0.9);
    float crack = max(1.0 - smoothstep(0.0, 0.025, cr.y - cr.x), (1.0 - smoothstep(0.0, 0.03, cr2.y - cr2.x)) * 0.6) * P.f.z;
    c = mix(c, P.colorC.rgb, speck);
    c = mix(c, c * 0.55, crack * 0.6);
    s.albedo = c;
    s.rough = sat(P.f.w + speck * 0.15 + (1.0 - v) * 0.08);
    s.height = 0.5 + runs * 0.03 * P.f.y + speck * 0.02 - crack * 0.02;
    s.ao = 1.0 - crack * 0.1;
    s.metal = 0.0; s.alpha = 1.0;
    return s;
}

// Hand-woven chair cane, classic seven-step octagonal pattern with open holes (cutout).
// colorA cane, colorB shadowed/edge, f.x cells per tile, f.y strand width (cell units),
// f.z roughness, f.w aging (darker, less glossy).
S caneWeave(float2 uv, constant RFParams &P) {
    S s = defaults(); uint sd = P.seed;
    float N = max(2.0, floor(P.f.x + 0.5));
    float2 p = uv * N; float2 cell = floor(p); float2 f = p - cell;
    float w = P.f.y;
    // Octagonal hole at each cell center, bounded by horizontal and vertical strand pairs on the cell
    // edges and the two diagonal "setting" strands cutting the hole corners.
    float2 q = abs(f - 0.5);
    float ha = 0.5 - w * 1.1;                  // half-size of the square hole
    float hb = ha * 1.42;                      // octagon corner cut
    float best = -1.0, top = 0.0, prof = 0.0; float shade = 0.0;
    // Each strand: distance into the strand from its inner edge, strand width, stacking layer.
    float3 st[4];
    st[0] = float3(q.y - ha, w * 1.1, 0.10 + 0.15 * fmod(cell.x, 2.0));        // horizontal pair
    st[1] = float3(q.x - ha, w * 1.1, 0.18 + 0.15 * fmod(cell.y + 1.0, 2.0));  // vertical pair
    float dg = (q.x + q.y - hb) * 0.7071;
    float sideD = (f.x - 0.5) * (f.y - 0.5) > 0.0 ? 1.0 : 0.0;
    st[2] = float3(dg * sideD - (1.0 - sideD), w * 0.8, 0.32);
    st[3] = float3(dg * (1.0 - sideD) - sideD, w * 0.8, 0.30);
    for (int i = 0; i < 4; i++) {
        float d = st[i].x;
        if (d > 0.0) {
            // Pairs: two round strands side by side across the band.
            float t = fract(min(d / st[i].y, 0.999) * (i < 2 ? 2.0 : 1.0));
            float pr = sqrt(sat(1.0 - (2.0 * t - 1.0) * (2.0 * t - 1.0)));
            float hgt = st[i].z + pr * 0.3;
            if (hgt > best) { best = hgt; prof = pr; top = st[i].z; shade = float(i); }
        }
    }
    float a = best > 0.0 ? 1.0 : 0.0;
    float tone = h01(int2(wrapc(int2(cell), int2(int(N)))), sd + uint(shade) * 7u);
    float grain = gnoise(uv * float2(240, 240), int2(240, 240), sd + 3u);
    float3 c = mix(P.colorB.rgb, P.colorA.rgb, sat(0.35 + prof * 0.7)) * (0.9 + tone * 0.18 + grain * 0.04);
    c = mix(c, c * float3(0.7, 0.6, 0.5), P.f.w);
    s.albedo = c;
    s.alpha = a;
    s.height = a * (0.3 + top + prof * 0.3);
    s.rough = sat(P.f.z + (1.0 - prof) * 0.15 + P.f.w * 0.3);
    s.ao = a > 0.0 ? 0.7 + 0.3 * prof : 0.5;
    s.metal = 0.0;
    return s;
}
"""#
