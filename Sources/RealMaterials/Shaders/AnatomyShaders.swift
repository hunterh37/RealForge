// Anatomy programs (hand overlay): cortical bone, hyaline cartilage, skeletal muscle, tendon,
// blood-vessel wall, peripheral nerve. Tubes and lofts put u around and v along the structure, so
// fibers run along v.

let metalAnatomy = #"""
// ---------------------------------------------------------------- anatomy
// Cortical bone surface: ivory periosteal bone with longitudinal lamellar grain along v, vascular
// pores, a few nutrient foramina, and faint yellow-brown marrow staining.
// colorA base, colorB stain, colorC pore shade. f.x pores per tile, f.y grain strength,
// f.z roughness, f.w stain amount.
S boneCortical(float2 uv, constant RFParams &P) {
    S s = defaults(); uint sd = P.seed;
    float macro = fbm(uv, int2(3, 2), 4, sd + 1u);
    float grain = fbm(uv, int2(48, 3), 3, sd + 2u) * 0.6 + fbm(uv, int2(140, 6), 2, sd + 3u) * 0.4;
    float stain = smoothstep(0.05, 0.45, fbm(uv, int2(4, 3), 4, sd + 4u)) * P.f.w;
    float3 c = P.colorA.rgb * (0.94 + 0.08 * macro + 0.05 * grain * P.f.y);
    c = mix(c, P.colorB.rgb, stain * 0.55);
    float h = 0.5 + grain * 0.06 * P.f.y + macro * 0.05;
    // Vascular pores: tiny elongated pits.
    int F = max(8, int(P.f.x));
    float4 w = worley(uv, int2(F, max(1, F / 3)), sd + 5u, 0.9);
    float pore = (1.0 - smoothstep(0.03, 0.09, w.x)) * step(0.55, w.z);
    c = mix(c, P.colorC.rgb, pore * 0.6);
    h -= pore * 0.12;
    // Nutrient foramina: rare larger openings with a raised lip.
    float4 w2 = worley(uv, int2(3, 3), sd + 6u, 0.8);
    float hole = (1.0 - smoothstep(0.02, 0.035, w2.x)) * step(0.7, w2.z);
    float lip = (1.0 - smoothstep(0.035, 0.06, w2.x)) * step(0.7, w2.z) - hole;
    c = mix(c, P.colorC.rgb * 0.5, hole); h += lip * 0.05 - hole * 0.3;
    float rough = P.f.z * (0.9 + 0.2 * macro) + pore * 0.1;
    s.albedo = c; s.height = h; s.rough = clamp(rough, 0.2, 1.0); s.ao = 1.0 - pore * 0.4 - hole * 0.6;
    return s;
}

// Hyaline articular cartilage: smooth, wet, translucent blue-white with soft mottling.
// colorA base, colorB deeper tone. f.x mottle scale, f.z roughness.
S cartilageHyaline(float2 uv, constant RFParams &P) {
    S s = defaults(); uint sd = P.seed;
    int F = max(2, int(P.f.x));
    float m = fbm(uv, int2(F, F), 4, sd + 1u);
    float fine = fbm(uv, int2(F * 12, F * 12), 2, sd + 2u);
    s.albedo = mix(P.colorA.rgb, P.colorB.rgb, sat(0.35 + m * 0.9));
    s.albedo *= 0.98 + fine * 0.04;
    s.height = 0.5 + m * 0.02 + fine * 0.01;
    s.rough = clamp(P.f.z * (0.9 + 0.2 * m), 0.08, 1.0);
    return s;
}

// Skeletal muscle under its epimysium: fascicles along v separated by pale perimysium, individual
// fibers inside, fiber angle for pennate muscles, translucent fascia sheen, small surface vessels.
// colorA muscle red, colorB deep shade, colorC fascia (a = amount). f.x fascicles per tile across u,
// f.y pennation angle (radians), f.z roughness, f.w vessel amount.
S muscleFiber(float2 uv, constant RFParams &P) {
    S s = defaults(); uint sd = P.seed;
    float2 r = rot2(uv, P.f.y);
    int F = max(4, int(P.f.x));
    // Fascicles: cells long along v.
    float4 w = worley(r, int2(F, max(1, F / 8)), sd + 1u, 0.85);
    float border = 1.0 - smoothstep(0.0, 0.12, w.y - w.x);
    float fibers = gnoise(float2(r.x * float(F) * 9.0, r.y * 3.0), int2(F * 9, 3), sd + 2u);
    float fibers2 = gnoise(float2(r.x * float(F) * 23.0, r.y * 5.0), int2(F * 23, 5), sd + 3u);
    float tone = (w.z - 0.5) * 0.18;
    float3 c = P.colorA.rgb * (0.92 + tone + 0.1 * fibers + 0.05 * fibers2);
    c = mix(c, P.colorB.rgb, sat(border * 0.7 + (0.5 - w.z) * 0.3));
    // Perimysium: thin pale septa between fascicles.
    float septa = 1.0 - smoothstep(0.0, 0.03, w.y - w.x);
    c = mix(c, P.colorC.rgb * 0.75 + P.colorA.rgb * 0.25, septa * 0.55);
    // Epimysium sheen: streaky translucent white film.
    float film = smoothstep(0.1, 0.6, fbm(float2(r.x, r.y * 0.3), int2(6, 2), 4, sd + 4u)) * P.colorC.a;
    c = mix(c, P.colorC.rgb, film * 0.35);
    // Surface vessels: branching thin red-purple lines.
    float v = ridged(uv, int2(3, 3), 4, sd + 5u);
    float vessel = smoothstep(0.86, 0.96, v) * P.f.w;
    c = mix(c, P.colorB.rgb * float3(0.8, 0.5, 0.9), vessel * 0.6);
    s.albedo = c;
    s.height = 0.5 + 0.08 * fibers + 0.03 * fibers2 - border * 0.12 + vessel * 0.04 + film * 0.02;
    s.rough = clamp(P.f.z * (1.0 - film * 0.45) + border * 0.1, 0.12, 1.0);
    s.ao = 1.0 - border * 0.35;
    return s;
}

// Tendon and aponeurosis: dense parallel collagen along v with the crimp pattern (fine transverse
// waves), silvery pearlescent white. colorA base, colorB shade. f.x fiber bundles across u,
// f.y crimp strength, f.z roughness.
S tendonFiber(float2 uv, constant RFParams &P) {
    S s = defaults(); uint sd = P.seed;
    int F = max(4, int(P.f.x));
    float bundles = gnoise(float2(uv.x * float(F), uv.y * 2.0), int2(F, 2), sd + 1u);
    float fib = gnoise(float2(uv.x * float(F) * 8.0, uv.y * 4.0), int2(F * 8, 4), sd + 2u);
    float phase = gnoise(float2(uv.x * float(F) * 2.0, uv.y), int2(F * 2, 1), sd + 3u) * 6.0;
    float crimp = 0.5 + 0.5 * sin(uv.y * 6.2831853 * 90.0 + phase);
    crimp = pow(crimp, 3.0) * P.f.y;
    float3 c = mix(P.colorB.rgb, P.colorA.rgb, sat(0.6 + bundles * 0.6 + fib * 0.3 + crimp * 0.25));
    s.albedo = c;
    s.height = 0.5 + bundles * 0.05 + fib * 0.04 + crimp * 0.05;
    s.rough = clamp(P.f.z * (0.85 + 0.25 * (0.5 - crimp)), 0.1, 1.0);
    return s;
}

// Vessel wall: smooth adventitia with faint longitudinal striation and vasa vasorum capillaries.
// colorA blood tone through the wall, colorB capillary color, colorC highlight film.
// f.x capillary density, f.y striation, f.z roughness.
S vesselWall(float2 uv, constant RFParams &P) {
    S s = defaults(); uint sd = P.seed;
    float stri = gnoise(float2(uv.x * 40.0, uv.y * 2.0), int2(40, 2), sd + 1u) * P.f.y;
    float m = fbm(uv, int2(3, 6), 4, sd + 2u);
    float3 c = P.colorA.rgb * (0.9 + 0.15 * m + 0.08 * stri);
    int F = max(2, int(P.f.x));
    float cap = smoothstep(0.88, 0.97, ridged(uv, int2(F, F * 2), 4, sd + 3u));
    c = mix(c, P.colorB.rgb, cap * 0.7);
    float film = smoothstep(0.2, 0.7, fbm(uv, int2(2, 8), 3, sd + 4u));
    c = mix(c, P.colorC.rgb, film * 0.12);
    s.albedo = c;
    s.height = 0.5 + stri * 0.03 + cap * 0.03;
    s.rough = clamp(P.f.z * (1.0 - film * 0.3), 0.1, 1.0);
    return s;
}

// Peripheral nerve: pale yellow epineurium over visible fascicles, periodic bands of Fontana.
// colorA base, colorB fascicle shade. f.x fascicles across u, f.y band strength, f.z roughness.
S nerveFascicle(float2 uv, constant RFParams &P) {
    S s = defaults(); uint sd = P.seed;
    int F = max(3, int(P.f.x));
    float4 w = worley(uv, int2(F, 1), sd + 1u, 0.7);
    float border = 1.0 - smoothstep(0.0, 0.15, w.y - w.x);
    float band = pow(0.5 + 0.5 * sin(uv.y * 6.2831853 * 60.0 + w.z * 6.0), 6.0) * P.f.y;
    float3 c = mix(P.colorA.rgb, P.colorB.rgb, border * 0.6);
    c *= 0.95 + band * 0.1;
    s.albedo = c;
    s.height = 0.5 - border * 0.1 + band * 0.03;
    s.rough = clamp(P.f.z, 0.1, 1.0);
    return s;
}
"""#
