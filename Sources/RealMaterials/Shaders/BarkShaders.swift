// Bark programs: barkOak, barkBirch, barkPine.

let metalBark = #"""
// ---------------------------------------------------------------- bark
S barkOak(float2 uv, constant RFParams &P) {
    S s = defaults(); uint sd = P.seed;
    // Furrows are zero-crossings of anisotropic noise: a meandering, mostly vertical crevice network
    // between broad plates (mature oak). Two scales: main furrows + finer splits.
    float2 warp = float2(fbm(uv, int2(3, 2), 4, sd + 1u), fbm(uv, int2(3, 3), 3, sd + 2u));
    float2 q = uv + warp * 0.04;
    float g1 = gnoise(q * float2(11, 3), int2(11, 3), sd + 3u) + 0.35 * gnoise(q * float2(22, 6), int2(22, 6), sd + 4u);
    float g2 = gnoise(q * float2(26, 5), int2(26, 5), sd + 5u);
    float fA = 1.0 - smoothstep(0.0, 0.16, abs(g1));
    float fB = (1.0 - smoothstep(0.0, 0.07, abs(g2))) * smoothstep(-0.1, 0.25, fbm(uv, int2(5, 3), 3, sd + 9u));
    float furrow = max(fA, fB * 0.55);
    float bulge = smoothstep(0.0, 0.5, abs(g1));
    float fib = fbm(uv, int2(64, 8), 4, sd + 6u);
    float fine = fbm(uv, int2(32, 32), 3, sd + 7u);
    float plate = 1.0 - furrow;
    s.height = plate * (0.55 + 0.25 * bulge) + fib * 0.1 + fine * 0.08;
    float3 top = P.colorA.rgb * (0.8 + 0.35 * fbm(uv, int2(8, 4), 3, sd + 10u)) * (0.9 + 0.25 * fine);
    float3 deep = P.colorB.rgb * (0.8 + 0.4 * fib);
    s.albedo = mix(deep, top, smoothstep(0.1, 0.75, plate * (0.6 + 0.4 * bulge)));
    float lichen = smoothstep(0.08, 0.3, fbm(uv, int2(3, 4), 5, sd + 11u) + fine * 0.35) * smoothstep(0.5, 0.9, plate);
    s.albedo = mix(s.albedo, P.colorC.rgb * (0.8 + 0.4 * fib), lichen * P.f.x);
    float moss = smoothstep(0.1, 0.35, fbm(uv, int2(2, 2), 4, sd + 12u)) * furrow * P.f.y;
    s.albedo = mix(s.albedo, float3(0.03, 0.055, 0.012), moss);
    s.rough = mix(0.97, 0.84, plate) - lichen * 0.05;
    s.ao = mix(0.25, 1.0, smoothstep(0.0, 0.6, s.height));
    return s;
}
S barkBirch(float2 uv, constant RFParams &P) {
    S s = defaults(); uint sd = P.seed;
    float n = fbm(uv, int2(4, 4), 5, sd + 1u);
    float streak = fbm(uv, int2(3, 24), 3, sd + 2u);
    float3 base = P.colorA.rgb * (0.9 + 0.15 * n) + float3(0.02, 0.0, -0.02) * streak;
    // Lenticels: short horizontal dashes, one per Worley cell row.
    float4 lw = worley(uv, int2(5, 38), sd + 3u, 0.9);
    float2 lp = uv * float2(5.0, 38.0);
    float thin = 1.0 - smoothstep(0.05, 0.22, abs(fract(lp.y + lw.w * 0.5) - 0.5));
    float lent = smoothstep(0.42, 0.15, lw.x) * step(0.4, lw.z) * thin;
    // Dark diamond scars and rough black patches.
    float scar = smoothstep(0.32, 0.5, fbm(uv, int2(3, 5), 5, sd + 4u) + 0.25 * fbm(uv, int2(12, 6), 3, sd + 9u));
    float peel = smoothstep(0.2, 0.45, fbm(uv, int2(4, 10), 4, sd + 5u)) * (1.0 - scar);
    s.albedo = mix(base, P.colorC.rgb, peel * 0.6);
    s.albedo = mix(s.albedo, P.colorB.rgb, max(lent * 0.85, scar));
    s.height = 0.6 + n * 0.1 - lent * 0.3 - scar * (0.35 + 0.2 * fbm(uv, int2(24, 24), 3, sd + 6u)) + peel * 0.08;
    s.rough = mix(0.55, 0.92, max(scar, lent));
    s.ao = mix(1.0, 0.55, scar);
    return s;
}
S barkPine(float2 uv, constant RFParams &P) {
    S s = defaults(); uint sd = P.seed;
    float2 warp = float2(fbm(uv, int2(2, 2), 3, sd + 1u), fbm(uv, int2(2, 2), 3, sd + 2u)) * 0.08;
    float4 w = worley(uv + warp, int2(6, 4), sd + 3u, 0.9);
    float edge = w.y - w.x;
    float plate = smoothstep(0.03, 0.22, edge);
    float layer = floor(fbm(uv, int2(12, 8), 3, sd + 4u) * 6.0 + 3.0) / 6.0;   // flaky stacked layers
    float fine = fbm(uv, int2(40, 40), 3, sd + 5u);
    s.height = plate * (0.55 + 0.25 * layer + 0.15 * w.z) + fine * 0.08;
    float3 plateCol = mix(P.colorA.rgb, P.colorC.rgb, smoothstep(0.3, 0.7, layer + w.z * 0.3));
    s.albedo = mix(P.colorB.rgb, plateCol * (0.85 + 0.3 * fine), smoothstep(0.05, 0.6, plate));
    s.rough = mix(0.95, 0.85, plate);
    s.ao = mix(0.25, 1.0, smoothstep(0.0, 0.7, s.height));
    return s;
}
"""#
