// Recipe ingredient tissues (Miso recipe pack): beef marbling, salmon myomeres, fish skin, shrimp
// segments, hard cheese and rind, leaf blades, avocado flesh and skin, ground meat, bacon, broccoli
// florets, banana peel, mushroom cap. One program, mode in f.w.

let metalRecipe = #"""
// ---------------------------------------------------------------- recipe food tissues
// colorA main tissue, colorB second tone, colorC detail (fat, crystals, veins; a = strength).
// f.x structure cells per tile, f.y detail amount, f.z roughness, f.w mode:
// 0 beef lean with intramuscular marbling, 1 salmon flesh (myomere chevrons with white fat lines,
// bands across u), 2 fish skin (overlapping scales, dark back toward v = 0), 3 shrimp (segment
// bands along v, translucent body, dorsal stripe), 4 hard cheese (tyrosine crystals, fissures),
// 5 cheese rind (waxy mottle, pin dots), 6 leaf blade (veins across u from a midrib at u = 0.5,
// areoles), 7 avocado flesh (radial, centered at uv 0.5: yellow core to green rim, dark skin line),
// 8 avocado skin (pebbled domes), 9 coarse ground meat (grind worms, fat specks), 10 bacon (wavy
// fat and lean bands across u), 11 broccoli floret beads, 12 banana peel (ridges along v,
// freckles), 13 mushroom cap (fibrils, fine speckle).
S foodTissue(float2 uv, constant RFParams &P) {
    S s = defaults(); uint sd = P.seed;
    int mode = int(P.f.w + 0.5);
    int F = max(2, int(P.f.x));
    float macro = fbm(uv, int2(3, 3), 4, sd + 1u);
    float mid = fbm(uv, int2(12, 12), 3, sd + 2u);
    float fine = fbm(uv, int2(64, 64), 2, sd + 3u);
    float3 c = P.colorA.rgb;
    float h = 0.5, rough = P.f.z, ao = 1.0;
    if (mode == 0) {
        // Lean: fiber bundles along u, deep tone variation; marbling: lacy fat at two scales, gated
        // into patches, plus thin feathered threads along the fibers.
        float fib = gnoise(float2(uv.x * 4.0, uv.y * float(F) * 3.0), int2(4, F * 3), sd + 4u);
        c = mix(P.colorA.rgb, P.colorB.rgb, sat(0.45 + macro * 1.1 + fib * 0.25));
        c *= 0.92 + 0.06 * fine + 0.06 * fib;
        float2 wp = uv + 0.05 * float2(mid, macro);
        float net = ridged(wp, int2(F, F), 4, sd + 5u);
        float net2 = ridged(wp * 1.0 + 0.37, int2(F * 2 + 1, F * 2 + 1), 3, sd + 15u);
        float gate = smoothstep(-0.25, 0.2, fbm(uv, int2(3, 3), 3, sd + 6u));
        float gate2 = smoothstep(-0.1, 0.3, fbm(uv, int2(5, 5), 3, sd + 16u));
        float fat = smoothstep(0.66, 0.84, net) * gate * P.f.y;
        fat = max(fat, smoothstep(0.74, 0.9, net2) * gate2 * P.f.y * 0.85);
        float thr = 1.0 - smoothstep(0.0, 0.05, abs(gnoise(float2(uv.x * 3.0, uv.y * float(F) * 2.0), int2(3, F * 2), sd + 7u)));
        fat = max(fat, thr * smoothstep(0.1, 0.4, fbm(uv, int2(4, 8), 3, sd + 17u)) * P.f.y * 0.6);
        float soft = smoothstep(0.0, 1.0, fat);
        c = mix(c, mix(P.colorC.rgb, P.colorA.rgb, 0.25), smoothstep(0.0, 0.35, fat) * 0.35);
        c = mix(c, P.colorC.rgb * (0.93 + 0.1 * fine), soft * 0.92);
        h += fib * 0.03 + fat * 0.025 + fine * 0.025;
        rough = P.f.z * (0.85 + 0.35 * fat + 0.25 * smoothstep(0.0, 0.4, mid));
    } else if (mode == 1) {
        // Myomere bands: W-shaped lines across u (uneven spacing), soft pale fat, fine flake gaps.
        float vv = uv.y + 0.04 * mid;
        float chev = abs(fract(vv * 2.0) - 0.5) * 0.3 + 0.04 * sin(vv * 18.85);
        float bandPos = uv.x * float(F) + chev * float(F) * 0.22 + 0.5 * macro + 0.12 * sin(uv.x * 6.2831853 * 2.0);
        float d = abs(fract(bandPos) - 0.5);
        float wid = 0.03 + 0.03 * sat(0.5 + fbm(uv, int2(4, 8), 3, sd + 18u));
        float line = 1.0 - smoothstep(wid * 0.4, wid * 1.6, 0.5 - d);
        float line2 = 1.0 - smoothstep(0.0, 0.025, 0.5 - d);
        float side = d - 0.25;
        c = mix(P.colorA.rgb, P.colorB.rgb, sat(0.5 + macro * 1.0 + side * 0.9));
        c *= 0.94 + 0.07 * fine;
        c = mix(c, P.colorC.rgb, line * 0.6 * P.f.y * (0.7 + 0.3 * sat(0.5 + mid)));
        h += -line2 * 0.05 + d * 0.035 + fine * 0.015;
        ao -= line2 * 0.1;
        rough = P.f.z * (0.85 + 0.4 * line);
    } else if (mode == 2) {
        float2 g = float2(uv.x * float(F), uv.y * float(F) * 1.6);
        float row = floor(g.y);
        float2 q = float2(g.x + 0.5 * fmod(row, 2.0), g.y);
        float2 f = fract(q) - float2(0.5, 0.0);
        float scale = sat(1.0 - length(f * float2(1.0, 0.8)) * 1.6);
        float back = smoothstep(0.75, 0.1, uv.y + 0.15 * macro);
        c = mix(P.colorA.rgb, P.colorB.rgb, sat(back * 0.9 + mid * 0.3));
        c *= 0.88 + 0.18 * scale + 0.05 * fine;
        float irid = smoothstep(0.2, 0.6, fbm(uv, int2(6, 6), 3, sd + 8u)) * P.colorC.a;
        c = mix(c, P.colorC.rgb, irid * 0.25 * (1.0 - back));
        h += scale * 0.05 * P.f.y + fine * 0.01;
        rough = P.f.z * (0.8 + 0.4 * (1.0 - scale));
    } else if (mode == 3) {
        float seg = fract(uv.y * float(F) + 0.05 * mid);
        float edge = 1.0 - smoothstep(0.0, 0.12, min(seg, 1.0 - seg));
        c = mix(P.colorA.rgb, P.colorB.rgb, sat(0.4 + macro * 0.8));
        c = mix(c, P.colorB.rgb * 0.8, edge * 0.5 * P.f.y);
        float stripe = 1.0 - smoothstep(0.02, 0.07, abs(fract(uv.x + 0.25) - 0.5));
        c = mix(c, P.colorC.rgb, stripe * P.colorC.a * 0.6);
        float speck = smoothstep(0.35, 0.55, fine) * 0.1;
        c *= 0.95 + speck;
        h += seg * 0.04 - edge * 0.05 + fine * 0.01;
        ao -= edge * 0.1;
        rough = P.f.z * (0.9 + 0.2 * edge);
    } else if (mode == 4) {
        c = mix(P.colorA.rgb, P.colorB.rgb, sat(0.5 + macro * 0.8)) * (0.95 + 0.06 * mid);
        float4 w = worley(uv, int2(F, F), sd + 9u, 1.0);
        float crystal = (1.0 - smoothstep(0.05, 0.11, w.x)) * step(0.5, w.z) * P.f.y;
        c = mix(c, P.colorC.rgb, crystal * 0.85);
        float fis = smoothstep(0.8, 0.95, ridged(uv, int2(4, 4), 3, sd + 10u)) * P.f.y;
        c = mix(c, P.colorB.rgb * 0.75, fis * 0.4);
        float4 w2 = worley(uv, int2(F * 3, F * 3), sd + 11u, 1.0);
        float pit = (1.0 - smoothstep(0.03, 0.1, w2.x)) * step(0.85, w2.z);
        h += crystal * 0.04 - fis * 0.12 - pit * 0.08 + fine * 0.05;
        ao -= fis * 0.25 + pit * 0.15;
        rough = P.f.z * (1.0 - crystal * 0.4);
    } else if (mode == 5) {
        c = mix(P.colorA.rgb, P.colorB.rgb, sat(0.5 + macro * 1.1 + mid * 0.4));
        c *= 0.93 + 0.08 * fine;
        float4 w = worley(uv, int2(F, F), sd + 12u, 0.2);
        float dot_ = (1.0 - smoothstep(0.06, 0.12, w.x)) * P.f.y;
        c = mix(c, P.colorC.rgb, dot_ * 0.5);
        h += mid * 0.05 + fine * 0.04 - dot_ * 0.06;
        rough = P.f.z * (0.9 + 0.2 * fine);
    } else if (mode == 6) {
        float du = uv.x - 0.5;
        float mr = 1.0 - smoothstep(0.004, 0.018, abs(du));
        float side = du > 0.0 ? 1.0 : -1.0;
        float vein = abs(fract(uv.y * float(F) - abs(du) * 1.6 + 0.04 * mid) - 0.5);
        float lat = (1.0 - smoothstep(0.015, 0.05, vein)) * smoothstep(0.02, 0.06, abs(du));
        float4 w = worley(uv, int2(F * 4, F * 4), sd + 13u + uint(side + 1.0), 0.9);
        float areole = 1.0 - smoothstep(0.0, 0.07, w.y - w.x);
        c = mix(P.colorA.rgb, P.colorB.rgb, sat(0.45 + macro * 0.9));
        c *= 0.94 + 0.06 * w.z;
        c = mix(c, P.colorC.rgb, sat(mr * 0.8 + lat * 0.45 + areole * 0.12) * P.f.y);
        h += mr * 0.06 + lat * 0.03 - areole * 0.01 + fine * 0.01;
        rough = P.f.z * (0.9 + 0.2 * lat);
    } else if (mode == 7) {
        float2 p = (uv - 0.5) * 2.0;
        float r = length(p * float2(1.0, 1.0)) * (1.0 + 0.04 * macro);
        float t = smoothstep(0.26, 0.43, r);
        c = mix(P.colorA.rgb, P.colorB.rgb, t);
        c *= 0.96 + 0.05 * fine + 0.03 * mid;
        float rim = smoothstep(1.12, 1.2, r);
        c = mix(c, P.colorC.rgb, rim * 0.8);
        float strand = smoothstep(0.88, 0.97, ridged(uv, int2(6, 6), 3, sd + 14u)) * P.f.y;
        c = mix(c, P.colorB.rgb * 0.8, strand * 0.25);
        h += fine * 0.02;
        rough = P.f.z * (0.9 + 0.2 * fine);
    } else if (mode == 8) {
        float4 w = worley(uv, int2(F, F), sd + 15u, 1.0);
        float dome = sat(1.0 - w.x * 1.4);
        float4 w2 = worley(uv, int2(F * 3, F * 3), sd + 16u, 1.0);
        float dome2 = sat(1.0 - w2.x * 1.5);
        c = mix(P.colorA.rgb, P.colorB.rgb, sat(0.5 + macro * 1.2 + mid * 0.4));
        c *= 0.85 + 0.2 * dome;
        float spot = smoothstep(0.3, 0.6, fbm(uv, int2(5, 5), 3, sd + 17u)) * P.colorC.a;
        c = mix(c, P.colorC.rgb, spot * 0.5);
        h += dome * 0.12 * P.f.y + dome2 * 0.05;
        ao -= (1.0 - dome) * 0.15;
        rough = P.f.z * (1.1 - 0.3 * dome);
    } else if (mode == 9) {
        // Coarse grind: tangled extruded strands (ridged noise at two warps), each strand its own
        // lean shade, fat as broken pale strands, deep crevices between them.
        float2 wp = uv + 0.06 * float2(mid, macro);
        float s1 = ridged(wp, int2(F, F), 2, sd + 18u);
        float s2 = ridged(wp.yx + 0.31, int2(F, F), 2, sd + 28u);
        float strand = max(s1, s2 * 0.95);
        float crev = 1.0 - smoothstep(0.35, 0.6, strand);
        float shade = gnoise(wp * float(F) * 0.5, int2(F / 2, F / 2), sd + 19u);
        c = mix(P.colorA.rgb, P.colorB.rgb, sat(0.5 + shade * 1.2 + macro * 0.5));
        float fatS = smoothstep(0.78, 0.9, ridged(wp + 0.57, int2(F, F), 2, sd + 29u)) * smoothstep(-0.05, 0.25, fbm(uv, int2(6, 6), 2, sd + 30u));
        c = mix(c, P.colorC.rgb * (0.9 + 0.15 * fine), fatS * P.f.y * 0.85);
        c *= 1.0 - crev * 0.45;
        h += strand * 0.25 - crev * 0.1 + fine * 0.03;
        ao -= crev * 0.45;
        rough = P.f.z * (0.8 + 0.4 * crev);
    } else if (mode == 10) {
        float x = uv.x * float(F) + 0.35 * fbm(uv, int2(2, 4), 3, sd + 20u) * float(F) * 0.25;
        float b = 0.5 + 0.5 * sin(x * 6.2831853);
        float fat = smoothstep(0.62, 0.74, b + 0.35 * mid + 0.25 * macro);
        float edge = 1.0 - smoothstep(0.0, 0.08, abs(b - 0.55));
        float3 lean = mix(P.colorA.rgb, P.colorB.rgb, sat(0.5 + macro * 0.9));
        c = mix(lean, P.colorC.rgb * (0.94 + 0.08 * fine), fat);
        c = mix(c, P.colorB.rgb * 0.8, edge * 0.2);
        h += fat * 0.04 + fine * 0.02 + mid * 0.03 * P.f.y;
        rough = P.f.z * (0.8 + 0.3 * fat);
    } else if (mode == 11) {
        float4 w = worley(uv, int2(F, F), sd + 21u, 1.0);
        float bead = sat(1.0 - w.x * 1.3);
        float gap = 1.0 - smoothstep(0.0, 0.06, w.y - w.x);
        c = mix(P.colorA.rgb, P.colorB.rgb, sat(0.5 + macro * 0.9 + w.z * 0.2 - 0.1));
        c *= 0.85 + 0.2 * bead - 0.1 * gap;
        float yel = smoothstep(0.35, 0.6, fbm(uv, int2(4, 4), 3, sd + 22u)) * P.colorC.a;
        c = mix(c, P.colorC.rgb, yel * 0.3);
        h += bead * 0.2 * P.f.y - gap * 0.1;
        ao -= gap * 0.15;
        rough = P.f.z;
    } else if (mode == 12) {
        float ridge = 1.0 - abs(fract(uv.x * float(F)) - 0.5) * 2.0;
        float r2 = smoothstep(0.75, 1.0, ridge);
        c = mix(P.colorA.rgb, P.colorA.rgb * 0.88, sat(macro * 0.8 + 0.2));
        float4 w = worley(uv, int2(24, 24), sd + 23u, 1.0);
        float freckle = (1.0 - smoothstep(0.03, 0.1 + 0.06 * w.w, w.x)) * step(0.72, w.z) * P.f.y;
        c = mix(c, P.colorB.rgb, freckle * 0.8);
        float bruise = smoothstep(0.35, 0.55, fbm(uv, int2(3, 4), 3, sd + 24u)) * P.f.y;
        c = mix(c, P.colorB.rgb * 1.2, bruise * 0.2);
        c = mix(c, P.colorC.rgb, P.colorC.a * smoothstep(0.85, 1.0, abs(uv.y - 0.5) * 2.0));
        c *= 0.97 + 0.04 * fine;
        h += r2 * 0.06 + fine * 0.01;
        rough = P.f.z * (0.9 + 0.2 * freckle);
    } else {
        float fib = gnoise(float2(uv.x * float(F) * 2.0, uv.y * 3.0), int2(F * 2, 3), sd + 25u);
        c = mix(P.colorA.rgb, P.colorB.rgb, sat(0.5 + macro * 0.9 + fib * 0.15));
        c *= 0.95 + 0.06 * fine;
        float4 w = worley(uv, int2(F * 2, F * 2), sd + 26u, 1.0);
        float speck = (1.0 - smoothstep(0.03, 0.08, w.x)) * step(0.8, w.z) * P.f.y;
        c = mix(c, P.colorC.rgb, speck * 0.4);
        h += fib * 0.03 + fine * 0.02;
        rough = P.f.z * (0.9 + 0.15 * fine);
    }
    s.albedo = c; s.height = h; s.rough = clamp(rough, 0.04, 1.0); s.ao = sat(ao);
    return s;
}
"""#
