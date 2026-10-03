// Built-world programs: woodPlank, paintedMetal, rustMetal, concrete, asphalt, plastic, brick.

let metalBuilt = #"""
// ---------------------------------------------------------------- built world
S woodPlank(float2 uv, constant RFParams &P) {
    S s = defaults(); uint sd = P.seed;
    // Flat-sawn grain along U. Fine latewood lines (~1 cm apart at a 1 m tile) bent by a low-frequency
    // warp into long cathedral arches; medullary flecks and pores at high frequency; rare knots.
    float warp = fbm(uv, int2(1, 3), 4, sd + 1u) * 0.9 + fbm(uv, int2(2, 8), 3, sd + 2u) * 0.12;
    float figure = uv.y * 90.0 + warp * 14.0 + sin(uv.x * 6.2831853 * 1.0 + warp * 3.0) * 1.5;
    float r = fract(figure);
    float late = smoothstep(0.0, 0.08, r) * (1.0 - smoothstep(0.08, 0.45, r));
    float band = fbm(uv, int2(2, 12), 3, sd + 3u);                       // board-scale color bands
    float streak = fbm(uv, int2(3, 160), 3, sd + 4u);                    // fine streaks along grain
    float pores = smoothstep(0.3, 0.65, fbm(uv, int2(8, 400), 2, sd + 9u));
    float4 kw = worley(uv, int2(2, 3), sd + 5u, 0.8);
    float knotMask = step(0.82, kw.z);
    float2 kd = (uv * float2(2, 3) - floor(uv * float2(2, 3)));
    float knot = smoothstep(0.06, 0.0, kw.x) * knotMask;
    float knotRing = (0.5 + 0.5 * sin(kw.x * 260.0)) * smoothstep(0.16, 0.05, kw.x) * knotMask;
    float3 c = mix(P.colorA.rgb, P.colorB.rgb, sat(0.25 + band * 0.9 + streak * 0.25));
    c = mix(c, P.colorB.rgb * 0.75, late * 0.55);
    c *= 1.0 - pores * 0.06;
    c = mix(c, P.colorB.rgb * 0.45, max(knot, knotRing * 0.4));
    float weather = P.f.x;
    float3 grey = float3(0.29, 0.28, 0.26) * (0.85 + 0.35 * streak + 0.2 * band);
    c = mix(c, mix(grey, grey * 0.7, late), weather);
    s.albedo = c;
    s.height = 0.5 - late * 0.04 * (1.0 + weather * 6.0) + streak * 0.05 * (1.0 + weather * 4.0) - knot * 0.1 - pores * 0.03;
    s.rough = mix(P.f.y, 0.92, weather) + late * 0.04 + pores * 0.04;
    s.ao = 1.0 - late * 0.25 * weather;
    (void)kd;
    return s;
}
S paintedMetal(float2 uv, constant RFParams &P) {
    S s = defaults(); uint sd = P.seed;
    float peel = fbm(uv, int2(48, 48), 3, sd + 1u);                 // orange peel
    float wear = fbm(uv, int2(5, 5), 5, sd + 2u);
    float chip = smoothstep(0.24, 0.27, wear * 1.6 + 0.15 * fbm(uv, int2(40, 40), 2, sd + 3u) - (1.0 - P.f.x) * 0.3);
    float scratch = 0.0;
    for (int i = 0; i < 3; i++) {
        float a = h01u(sd + uint(i) * 11u) * 3.14159;
        int2 fr = int2(4 * (i + 1), 160);
        float2 r = rot2(uv - 0.5, a) + 0.5;
        float sn = gnoise(fract(r) * float2(fr), fr, sd + 20u + uint(i));
        scratch = max(scratch, (1.0 - smoothstep(0.0, 0.02, abs(sn))) * smoothstep(0.2, 0.5, fbm(uv, int2(3, 3), 3, sd + 30u + uint(i))));
    }
    scratch *= P.f.x;
    float dirt = smoothstep(-0.1, 0.4, fbm(uv, int2(3, 3), 5, sd + 4u)) * P.f.y;
    float3 paint = P.colorA.rgb * (0.95 + 0.1 * peel);
    float3 bare = float3(0.56, 0.55, 0.53);
    float3 primer = P.colorC.rgb;
    s.albedo = mix(paint, primer, chip);
    s.albedo = mix(s.albedo, bare, scratch * 0.8);
    s.albedo = mix(s.albedo, s.albedo * float3(0.45, 0.4, 0.33), dirt * 0.6);
    s.metal = max(scratch * 0.9, chip * P.colorC.a);
    s.rough = mix(P.f.z, 0.35, scratch) + dirt * 0.25 + chip * 0.3;
    s.height = 0.6 + peel * 0.02 - chip * 0.25 - scratch * 0.1;
    s.ao = 1.0 - dirt * 0.2;
    return s;
}
S rustMetal(float2 uv, constant RFParams &P) {
    S s = defaults(); uint sd = P.seed;
    float n = fbm(uv, int2(4, 4), 6, sd + 1u);
    float pits = smoothstep(0.25, 0.05, worley(uv, int2(40, 40), sd + 2u, 1.0).x) * 0.6;
    float bare = smoothstep(0.1, 0.25, -n - (1.0 - P.f.x) * 0.3);
    float3 rust = mix(P.colorA.rgb, P.colorB.rgb, smoothstep(-0.3, 0.4, fbm(uv, int2(12, 12), 4, sd + 3u)));
    s.albedo = mix(rust, float3(0.5, 0.49, 0.47), bare) * (1.0 - pits * 0.5);
    s.metal = bare; s.rough = mix(0.88, 0.45, bare);
    s.height = 0.5 + n * 0.3 - pits * 0.3; s.ao = 1.0 - pits * 0.4;
    return s;
}
S concrete(float2 uv, constant RFParams &P) {
    S s = defaults(); uint sd = P.seed;
    float n = fbm(uv, int2(4, 4), 6, sd + 1u);
    float4 ag = worley(uv, int2(55, 55), sd + 2u, 1.0);
    float stone = smoothstep(0.4, 0.3, ag.x) * step(0.6, ag.z);
    float4 pw = worley(uv, int2(220, 220), sd + 3u, 1.0);
    float pore = smoothstep(0.14, 0.05, pw.x) * step(0.8, pw.z);
    float stain = smoothstep(0.0, 0.5, fbm(uv, int2(2, 2), 5, sd + 4u)) * P.f.y;
    float3 c = P.colorA.rgb * (0.85 + 0.3 * n);
    c = mix(c, P.colorB.rgb * (0.8 + 0.5 * ag.w), stone * 0.6);
    c *= 1.0 - pore * 0.6;
    c = mix(c, c * float3(0.6, 0.58, 0.52), stain);
    s.albedo = c; s.height = 0.5 + n * 0.15 + stone * 0.05 - pore * 0.2;
    s.rough = P.f.x + 0.08 * n + stain * 0.05; s.ao = 1.0 - pore * 0.5;
    return s;
}
S asphalt(float2 uv, constant RFParams &P) {
    S s = defaults(); uint sd = P.seed;
    float4 ag = worley(uv, int2(80, 80), sd + 1u, 1.0);
    float stone = smoothstep(0.5, 0.25, ag.x);
    float n = fbm(uv, int2(6, 6), 5, sd + 2u);
    float3 c = mix(P.colorA.rgb, P.colorB.rgb * (0.6 + 0.8 * ag.z), stone * step(0.35, ag.w));
    float4 cr = worley(uv, int2(3, 3), sd + 3u, 1.0);
    float crack = (1.0 - smoothstep(0.0, 0.012, cr.y - cr.x)) * smoothstep(0.2, 0.4, n + P.f.x * 0.3);
    s.albedo = c * (0.85 + 0.3 * n) * (1.0 - crack * 0.7);
    s.height = 0.5 + stone * 0.3 - (1.0 - stone) * 0.1 - crack * 0.5;
    s.rough = 0.88 - stone * 0.1; s.ao = mix(0.7, 1.0, stone) * (1.0 - crack * 0.5);
    return s;
}
S plastic(float2 uv, constant RFParams &P) {
    S s = defaults(); uint sd = P.seed;
    float n = fbm(uv, int2(8, 8), 4, sd + 1u);
    float sc = 0.0;
    for (int i = 0; i < 2; i++) {
        float a = h01u(sd + uint(i) * 5u) * 3.14159; int2 fr = int2(6, 120);
        float2 r = rot2(uv - 0.5, a) + 0.5;
        sc = max(sc, (1.0 - smoothstep(0.0, 0.03, abs(gnoise(fract(r) * float2(fr), fr, sd + 9u + uint(i))))) * smoothstep(0.1, 0.4, fbm(uv, int2(3, 3), 3, sd + 20u)));
    }
    float dirt = smoothstep(0.0, 0.5, fbm(uv, int2(3, 3), 5, sd + 3u)) * P.f.y;
    s.albedo = P.colorA.rgb * (0.95 + 0.08 * n) * (1.0 - sc * 0.15 * P.f.x);
    s.albedo = mix(s.albedo, s.albedo * float3(0.5, 0.45, 0.4), dirt * 0.5);
    s.rough = P.f.z + sc * 0.25 * P.f.x + dirt * 0.2 + n * 0.03;
    s.height = 0.5 + n * 0.02 - sc * 0.1 * P.f.x; s.ao = 1.0 - dirt * 0.15;
    return s;
}
S brick(float2 uv, constant RFParams &P) {
    S s = defaults(); uint sd = P.seed;
    // 4 courses x 2 bricks per tile, running bond.
    float2 g = uv * float2(2.0, 4.0);
    float row = floor(g.y); g.x += fmod(row, 2.0) * 0.5;
    float2 cell = floor(g); float2 f = fract(g);
    float2 mort = float2(0.035, 0.07);
    float2 e = min(f, 1.0 - f) / mort;
    float inBrick = smoothstep(0.6, 1.4, min(e.x, e.y));
    float id = h01(int2(fmod(cell.x + 2.0, 2.0), fmod(cell.y + 4.0, 4.0)), sd);
    float n = fbm(uv, int2(16, 16), 4, sd + 1u);
    float3 bc = mix(P.colorA.rgb, P.colorB.rgb, id) * (0.85 + 0.3 * n);
    float3 mc = P.colorC.rgb * (0.9 + 0.2 * fbm(uv, int2(40, 40), 3, sd + 2u));
    s.albedo = mix(mc, bc, inBrick);
    s.height = mix(0.2 + 0.1 * n, 0.7 + 0.1 * n - 0.15 * pow(1.0 - inBrick, 2.0), inBrick);
    s.rough = mix(0.95, 0.85, inBrick); s.ao = mix(0.55, 1.0, inBrick);
    return s;
}
"""#
