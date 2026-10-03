// Fabric and camp-wood programs: fabricWeave, woodEndGrain, charcoal.

let metalFabric = #"""
// ---------------------------------------------------------------- fabric and camp wood
// Plain weave. Warp threads run along V, weft along U; each passes over and under alternate crossings.
// colorA yarn, colorB second yarn tone (a = per-thread mix, 0 keeps tints clean), colorC dirt (a = dirt amount).
// knobs: x threads per tile (rounded to even), y fuzz and slubs, z base roughness, w ripstop cells per tile (0 = none).
S fabricWeave(float2 uv, constant RFParams &P) {
    S s = defaults(); uint sd = P.seed;
    int n = max(2, int(P.f.x * 0.5 + 0.5) * 2);
    float fn = float(n);
    float2 g = uv * fn;
    float2 cell = floor(g); float2 f = g - cell;
    int2 ci = wrapc(int2(cell), int2(n));
    float fuzz = P.f.y;
    // Per-thread thickness (slubs) varies along the thread; periodic along it, keyed by thread index.
    int sl = max(1, n / 4);
    float slubW = gnoise(float2(uv.y * float(sl), float(ci.x) * 0.37 + 0.5), int2(sl, 4096), sd + 3u);
    float slubF = gnoise(float2(uv.x * float(sl), float(ci.y) * 0.41 + 0.5), int2(sl, 4096), sd + 4u);
    float baseW = mix(0.86, 0.62, sat(fuzz * 1.4));               // thread width as a fraction of pitch
    float ww = baseW * (1.0 + slubW * 0.35 * (0.3 + fuzz));
    float wf = baseW * (1.0 + slubF * 0.35 * (0.3 + fuzz));
    // Ripstop: every k-th thread is doubled and stands proud.
    float rip = 0.0;
    if (P.f.w > 0.5) {
        int k = max(2, n / max(1, int(P.f.w + 0.5)));
        float rx = (ci.x % k == 0) ? 1.0 : 0.0, ry = (ci.y % k == 0) ? 1.0 : 0.0;
        ww *= 1.0 + rx * 0.25; wf *= 1.0 + ry * 0.25;
        rip = max(rx * (1.0 - smoothstep(0.3, 0.5, abs(f.x - 0.5))), ry * (1.0 - smoothstep(0.3, 0.5, abs(f.y - 0.5))));
    }
    // Over-under undulation, continuous across cells (n even keeps it periodic).
    float A = 0.22;
    float zW = A * cos(3.14159265 * (g.y - 0.5) + 3.14159265 * cell.x);
    float zF = -A * cos(3.14159265 * (g.x - 0.5) + 3.14159265 * cell.y);
    // Loose weaves wander: thread centers drift sideways along their length.
    float drift = 0.12 * fuzz;
    float cxW = 0.5 + drift * gnoise(float2(uv.y * float(sl) * 2.0, float(ci.x) * 0.53 + 0.5), int2(sl * 2, 4096), sd + 11u);
    float cyF = 0.5 + drift * gnoise(float2(uv.x * float(sl) * 2.0, float(ci.y) * 0.59 + 0.5), int2(sl * 2, 4096), sd + 12u);
    float dW = abs(f.x - cxW) / (ww * 0.5), dF = abs(f.y - cyF) / (wf * 0.5);
    float pW = dW < 1.0 ? sqrt(1.0 - dW * dW) : -1.0;
    float pF = dF < 1.0 ? sqrt(1.0 - dF * dF) : -1.0;
    float hW = pW >= 0.0 ? 0.5 + zW + pW * 0.3 : -1.0;
    float hF = pF >= 0.0 ? 0.5 + zF + pF * 0.3 : -1.0;
    bool warpTop = hW >= hF;
    float h = max(hW, hF);
    float gap = h < 0.0 ? 1.0 : 0.0;
    // Fibers: twisted strands, a slanted fine stripe along each thread.
    float along = warpTop ? g.y : g.x, across = warpTop ? f.x : f.y;
    float twist = 0.5 + 0.5 * sin((along * 3.0 + across * 2.2) * 6.2831853);
    float hair = fbm(uv, int2(n * 2, n * 2), 3, sd + 5u);
    float profile = warpTop ? pW : pF;
    float yarnId = warpTop ? h01(int2(ci.x, 0), sd + 6u) : h01(int2(0, ci.y), sd + 7u);
    float3 yarn = mix(P.colorA.rgb, P.colorB.rgb, yarnId * P.colorB.a);
    yarn *= 0.9 + 0.1 * twist + 0.08 * hair;
    yarn *= mix(0.72, 1.0, sat(profile));
    // Fuzz: loose fibers lighten the surface and soften the weave.
    float halo = smoothstep(0.0, 0.5, fbm(uv, int2(n, n), 4, sd + 8u) + hair * 0.5) * fuzz;
    float3 c = gap > 0.5 ? yarn * 0.25 : yarn;
    c = mix(c, P.colorA.rgb * 1.08, halo * 0.35);
    c = mix(c, c * 0.92, rip * 0.4);
    // Broad mottling and dirt.
    float mott = fbm(uv, int2(3, 3), 4, sd + 9u);
    c *= 0.94 + 0.12 * mott;
    float dirt = smoothstep(-0.05, 0.45, fbm(uv, int2(2, 2), 5, sd + 10u)) * P.colorC.a;
    c = mix(c, P.colorC.rgb, dirt * 0.6);
    s.albedo = c;
    float hh = gap > 0.5 ? 0.0 : sat(h);
    s.height = mix(hh, 0.5, halo * 0.3) + twist * 0.03 * (1.0 - gap) + rip * 0.12;
    s.rough = sat(P.f.z + (1.0 - sat(profile)) * 0.08 + fuzz * 0.15 + dirt * 0.1 + gap * 0.1);
    s.ao = gap > 0.5 ? 0.45 : mix(0.7, 1.0, sat(profile));
    return s;
}

// End grain of a sawn log. The pith sits at the tile center and the bark edge at radius 0.42, so assets
// map each disc to fill that circle. Beyond the edge the pattern fades to plain tileable end grain.
// colorA earlywood, colorB latewood, colorC heartwood (a = heartwood radius, 0...1 of the disc).
// knobs: x ring count, y radial checks, z saw marks, w weathering (grey).
S woodEndGrain(float2 uv, constant RFParams &P) {
    S s = defaults(); uint sd = P.seed;
    float2 p = uv - 0.5;
    float warp = fbm(uv, int2(3, 3), 4, sd + 1u);
    float2 pe = p + float2(0.02, -0.015) * (0.5 + 0.5 * h01u(sd));          // eccentric pith
    float r = length(pe) / 0.42;
    float a = atan2(pe.y, pe.x);
    float inner = 1.0 - smoothstep(1.02, 1.12, r);
    float rw = r * (1.0 + warp * 0.06) + fbm(uv, int2(6, 6), 3, sd + 2u) * 0.01;
    float phase = pow(max(rw, 0.0), 0.88) * max(P.f.x, 4.0);
    phase += 0.8 * gnoise(float2(rw * 9.0, 0.5), int2(64, 4096), sd + 6u);   // wet and dry years
    float fr = fract(phase);
    float late = smoothstep(0.5, 0.82, fr) * (1.0 - smoothstep(0.9, 1.0, fr));
    // Plain tileable end grain outside the disc (pores, mottling).
    float pores = fbm(uv, int2(64, 64), 2, sd + 3u);
    float mott = fbm(uv, int2(8, 8), 3, sd + 4u);
    float3 ring = mix(P.colorA.rgb, P.colorB.rgb, fr * 0.2 + late * 0.6);
    float hb = P.colorC.a + warp * 0.1;
    float heart = (1.0 - smoothstep(hb - 0.07, hb + 0.05, r)) * (0.75 + 0.5 * mott);
    ring *= 1.0 - smoothstep(0.9, 1.0, r) * 0.18;                               // cambium shadow at the bark
    ring = mix(ring, ring * P.colorC.rgb / max(P.colorA.rgb, float3(0.05)), heart * 0.8);
    float pith = 1.0 - smoothstep(0.0, 0.04, r);
    ring = mix(ring, P.colorB.rgb * 0.6, pith);
    // Radial checks: drying cracks from the bark edge toward the pith.
    float check = 0.0;
    for (int i = 0; i < 6; i++) {
        float ang = h01u(sd + 40u + uint(i)) * 6.2831853;
        float len = mix(0.25, 0.75, h01u(sd + 60u + uint(i)));
        float d = abs(fmod(a - ang + 9.42477796, 6.2831853) - 3.14159265) * r * 0.42;
        float w = 0.006 * smoothstep(1.0 - len, 1.0, r);
        check = max(check, (1.0 - smoothstep(0.0, w + 1e-4, d)) * step(1.0 - len, r) * step(float(i) / 6.0, P.f.y));
    }
    // Saw marks: shallow parallel arcs across the face.
    float saw = sin((uv.y * 40.0 + fbm(uv, int2(2, 2), 2, sd + 5u) * 1.5 + p.x * p.x * 3.0) * 6.2831853);
    float3 c = mix(mix(P.colorA.rgb, P.colorB.rgb, 0.3 + mott * 0.4) * (0.95 + pores * 0.2), ring * (0.92 + pores * 0.12 + mott * 0.1), inner);
    c *= 1.0 - check * 0.75 * inner;
    c *= 1.0 + saw * 0.03 * P.f.z * inner;
    float3 grey = float3(0.36, 0.34, 0.31) * (0.85 + 0.3 * mott);
    c = mix(c, mix(grey, grey * 0.72, late), P.f.w * (0.6 + 0.4 * smoothstep(0.3, 1.0, r)) * inner + P.f.w * (1.0 - inner) * 0.5);
    s.albedo = c;
    s.height = 0.55 + (late * (0.03 + P.f.w * 0.12) + saw * 0.05 * P.f.z) * inner - check * 0.5 * inner + pores * 0.03 + mott * 0.04;
    s.rough = 0.82 + late * 0.05 + P.f.w * 0.08;
    s.ao = 1.0 - check * 0.6 * inner;
    return s;
}

// Charred wood: alligatored char blocks (deep cross-grain checks), ash bloom, unburnt wood in cracks.
// Grain runs along U like woodPlank. colorA char, colorB ash, colorC unburnt wood.
// knobs: x ash amount, y block density, z unburnt amount in cracks, w sheen (0 dull ... 1 silvery).
S charcoal(float2 uv, constant RFParams &P) {
    S s = defaults(); uint sd = P.seed;
    int by = max(2, int(P.f.y));
    float2 wv = float2(fbm(uv, int2(4, 4), 3, sd + 1u), fbm(uv, int2(4, 4), 3, sd + 2u)) * 0.03;
    // Alligator checks: cushioned blocks between deep cracks, with finer splits inside each block.
    float4 w = worley(uv + wv, int2(by, by), sd + 3u, 1.0);
    float4 w2 = worley(uv + wv, int2(by * 3, by * 2), sd + 4u, 1.0);
    float wide = 0.03 + 0.05 * sat(0.5 + fbm(uv, int2(3, 3), 3, sd + 5u) * 1.5);
    float crack = 1.0 - smoothstep(wide * 0.3, wide, w.y - w.x);
    float split = (1.0 - smoothstep(0.0, 0.05, w2.y - w2.x)) * 0.5;
    float dome = smoothstep(0.0, 0.3, w.y - w.x);
    float grain = fbm(uv, int2(4, 64), 3, sd + 6u);
    float fine = fbm(uv, int2(48, 48), 3, sd + 7u);
    float ashAmt = P.f.x;
    float3 c = P.colorA.rgb * (0.75 + 0.4 * w.z + 0.3 * grain + 0.15 * fine);
    float ash = smoothstep(0.0, 0.3, fbm(uv, int2(3, 3), 5, sd + 8u) + fine * 0.3 + min(ashAmt, 0.35) - 0.5) * dome;
    c = mix(c, P.colorB.rgb * (0.8 + 0.35 * fine + 0.15 * w.w), ash);
    float unburnt = crack * smoothstep(0.1, 0.45, fbm(uv, int2(2, 3), 4, sd + 9u) + P.f.z - 0.5);
    c = mix(c, P.colorC.rgb * (0.8 + 0.3 * grain), unburnt * 0.8);
    c *= 1.0 - (crack * (1.0 - unburnt) * 0.65 + split * 0.3);
    float h = 0.5 + (dome - 0.5) * 0.6 + w.w * 0.1 - split * 0.15 - crack * 0.2 + grain * 0.05 + fine * 0.04;
    float rough = mix(0.97, mix(0.85, 0.55, P.f.w), (1.0 - ash) * dome);
    float ao = mix(0.35, 1.0, dome) * (1.0 - split * 0.3);
    // High ash amounts turn most cells into flat powder, leaving scattered charcoal chunks.
    float ashCell = step(w.z, ashAmt * 1.2 - 0.3);
    float speck = fbm(uv, int2(96, 96), 2, sd + 10u);
    float3 powder = P.colorB.rgb * (0.7 + 0.25 * fine + 0.3 * speck) * (1.0 - smoothstep(0.1, 0.4, -speck) * 0.6);
    s.albedo = mix(c, powder, ashCell);
    s.height = mix(h, 0.3 + fine * 0.08 + speck * 0.04, ashCell);
    s.rough = mix(rough, 0.98, ashCell);
    s.ao = mix(ao, 0.9 + speck * 0.1, ashCell);
    return s;
}
"""#
