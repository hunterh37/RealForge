// Rock programs: strataRock (sedimentary bands), rockSlate (cleaved plates), rockRiver (water-worn stone).
// Bands run along u and stack in v, so triplanar side projections (v = object y) give horizontal strata.

let metalRock = #"""
// ---------------------------------------------------------------- rock
inline int wrapi(int i, int n) { return ((i % n) + n) % n; }

// Sedimentary strata. colorA dark band, colorB light band, colorC accent band (bleached or iron-rich).
// knobs: x band contrast, y bands per tile (>= 2), z erosion grooves between beds, w cross-bedding.
S strataRock(float2 uv, constant RFParams &P) {
    S s = defaults(); uint sd = P.seed;
    int nb = max(2, int(P.f.y + 0.5));
    float warp = 0.5 * fbm(uv, int2(3, 1), 4, sd + 1u) / float(nb) + 0.004 * fbm(uv, int2(12, 6), 3, sd + 2u);
    float v = uv.y + warp;
    float b = v * float(nb);
    b += 0.42 * gnoise(float2(0.5, b * 0.5), int2(1, max(1, nb / 2)), sd + 9u) + 0.18 * gnoise(float2(0.5, b * 1.5), int2(1, nb + nb / 2), sd + 10u);
    int bi = int(floor(b)); float t = b - floor(b);
    float hA = h01u(uint(wrapi(bi, nb)) * 977u + sd), hB = h01u(uint(wrapi(bi + 1, nb)) * 977u + sd);
    // Each bed: base color, hardness (protrudes), sharp boundary with a thin parting.
    float edge = smoothstep(0.9, 1.0, t);
    float h = mix(hA, hB, edge);
    float3 c = mix(P.colorA.rgb, P.colorB.rgb, mix(0.5, h, sat(P.f.x)));
    float acc = h01u(uint(wrapi(bi, nb)) * 131u + sd + 5u);
    if (acc < 0.18) c = mix(c, P.colorC.rgb, 0.7);
    // Laminae inside the bed, tilted for cross-bedding.
    float lamV = v + P.f.w * 0.06 * (fract(uv.x * 6.0 + hA * 3.0) - 0.5) * step(0.55, hA);
    float lam = gnoise(float2(uv.x * 2.0, lamV * float(nb * 9)), int2(2, nb * 9), sd + 3u);
    c *= 0.95 + 0.08 * lam;
    float n = fbm(uv, int2(16, 16), 4, sd + 4u);
    float grain = fbm(uv, int2(128, 128), 2, sd + 6u);
    c *= (0.88 + 0.24 * (n + 0.5)) * (0.94 + 0.12 * grain);
    // Desert varnish and rain streaks down the faces.
    float streak = smoothstep(0.0, 0.4, fbm(uv, int2(20, 2), 4, sd + 7u));
    c *= 1.0 - 0.22 * streak;
    // Joints: near-vertical cracks, offset per bed.
    float2 jq = float2(uv.x + 0.02 * fbm(uv, int2(8, 8), 3, sd + 11u), v * 0.25);
    float4 jw = worley(jq, int2(4, max(1, nb / 4)), sd + 8u, 1.0);
    float joint = (1.0 - smoothstep(0.0, 0.012, jw.y - jw.x)) * step(0.6, h01u(uint(wrapi(bi, nb)) * 71u + sd))
                * smoothstep(0.0, 0.25, fbm(uv, int2(6, 6), 3, sd + 12u));
    float parting = smoothstep(0.95, 0.99, t) * (1.0 - smoothstep(0.99, 1.0, t)) * (0.4 + 0.6 * abs(hA - hB));
    s.albedo = c * (1.0 - 0.35 * parting) * (1.0 - 0.4 * joint);
    float groove = sat(P.f.z) * (smoothstep(0.75, 1.0, t) * 0.5 + parting);
    s.height = 0.3 + 0.35 * h + 0.06 * lam + 0.12 * n + 0.03 * grain - 0.35 * groove - 0.25 * joint;
    s.rough = 0.86 + 0.06 * grain;
    s.ao = mix(0.5, 1.0, sat(1.0 - 1.4 * groove - 0.8 * joint));
    return s;
}

// Slate: thin plates stacked in v with chipped light edges, fine cleavage lines, rust stains.
// colorA slate, colorB lighter plate edges, colorC rust. knobs: x rust, y plates per tile (>= 2).
S rockSlate(float2 uv, constant RFParams &P) {
    S s = defaults(); uint sd = P.seed;
    int np = max(2, int(P.f.y + 0.5));
    float v = uv.y + 0.6 * fbm(uv, int2(4, 2), 4, sd + 1u) / float(np);
    float b = v * float(np); int pi = int(floor(b)); float t = b - floor(b);
    float hp = h01u(uint(wrapi(pi, np)) * 613u + sd);
    // Plate steps: each plate sits at its own height; the broken edge is a bright chipped band.
    float step0 = smoothstep(0.0, 0.05, t);
    float edge = (1.0 - smoothstep(0.0, 0.05, t)) * step(0.5, hp);
    float clv = gnoise(float2(uv.x * 3.0, v * float(np * 14)), int2(3, np * 14), sd + 2u);
    float n = fbm(uv, int2(10, 10), 4, sd + 3u);
    float3 c = P.colorA.rgb * (0.85 + 0.25 * hp) * (0.93 + 0.12 * clv) * (0.9 + 0.25 * (n + 0.5) * 0.6);
    c = mix(c, P.colorB.rgb, edge * 0.3);
    float rust = smoothstep(0.2, 0.5, fbm(uv, int2(5, 5), 5, sd + 4u)) * sat(P.f.x);
    c = mix(c, P.colorC.rgb, rust * (0.5 + 0.5 * fbm(uv, int2(40, 40), 2, sd + 5u)));
    float4 cr = worley(float2(uv.x, v * 0.5), int2(3, max(1, np / 4)), sd + 6u, 1.0);
    float crack = (1.0 - smoothstep(0.0, 0.01, cr.y - cr.x)) * smoothstep(0.05, 0.3, fbm(uv, int2(4, 4), 3, sd + 7u));
    s.albedo = c * (1.0 - 0.4 * crack);
    s.height = 0.25 + 0.4 * hp * step0 + 0.08 * clv + 0.1 * n - 0.3 * crack + 0.1 * (1.0 - step0);
    s.rough = 0.7 - 0.1 * (1.0 - edge) * hp + rust * 0.15;
    s.ao = mix(0.55, 1.0, step0) * (1.0 - 0.4 * crack);
    return s;
}

// Water-worn stone: smooth mottled surface, sand speckle, quartz veins.
// colorA base, colorB mottle, colorC veins. knobs: x wetness (darker, glossier), y veins.
S rockRiver(float2 uv, constant RFParams &P) {
    S s = defaults(); uint sd = P.seed;
    float m = fbm(uv, int2(4, 4), 5, sd + 1u);
    float m2 = fbm(uv, int2(12, 12), 3, sd + 2u);
    float3 c = mix(P.colorA.rgb, P.colorB.rgb, smoothstep(-0.3, 0.3, m + 0.4 * m2));
    float4 sp = worley(uv, int2(180, 180), sd + 3u, 0.9);
    float speck = smoothstep(0.35, 0.1, sp.x);
    c = mix(c, sp.z < 0.4 ? float3(0.03) : c * 1.35, speck * 0.35);
    // Veins: thin bands where a warped noise crosses zero.
    float vn = fbm(uv + 0.05 * float2(fbm(uv, int2(8, 8), 3, sd + 5u), 0.0), int2(2, 5), 4, sd + 4u);
    float vein = (1.0 - smoothstep(0.002, 0.008, abs(vn))) * smoothstep(0.0, 0.2, fbm(uv, int2(3, 3), 3, sd + 6u)) * sat(P.f.y);
    c = mix(c, P.colorC.rgb, vein * 0.6);
    float wet = sat(P.f.x);
    c *= mix(1.0, 0.58, wet);
    s.albedo = c;
    s.height = 0.5 + 0.08 * m + 0.03 * m2 + 0.01 * speck + 0.02 * vein;
    s.rough = mix(0.62 - 0.08 * vein, 0.2, wet) + 0.05 * m2;
    s.ao = 0.9 + 0.1 * smoothstep(-0.3, 0.3, m);
    return s;
}
"""#
