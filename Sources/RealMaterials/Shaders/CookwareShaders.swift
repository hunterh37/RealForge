// Cookware programs: end-grain butcher block, seasoned cast iron, heat-tinted stainless.

let metalCookware = #"""
// ---------------------------------------------------------------- cookware
// End-grain butcher block: a checker of glued end-grain blocks, each with ring arcs from a pith outside
// the block, open pores, dark glue lines and knife scoring. colorA light blocks (maple), colorB dark
// blocks (walnut), colorC glue line. f.x blocks per tile (integer), f.y rings per block, f.z knife
// marks, f.w base roughness.
S butcherBlock(float2 uv, constant RFParams &P) {
    S s = defaults(); uint sd = P.seed;
    int N = max(1, int(P.f.x + 0.5));
    float2 g = uv * float2(N); float2 cf = floor(g); float2 f = g - cf;
    int2 cell = wrapc(int2(cf), int2(N, N));
    bool dark = ((cell.x + cell.y) & 1) == 1;
    float id = h01(cell, sd + 3u), id2 = h01(cell, sd + 5u);
    // Pith 0.8-2.5 blocks away in a random direction: rings show as gentle arcs.
    float ang = id * 6.2831853, dist = mix(0.8, 2.5, id2);
    float2 pith = float2(0.5) + float2(cos(ang), sin(ang)) * dist;
    float2 wq = f + float2(fbm(uv, int2(N * 3, N * 3), 2, sd + 7u), fbm(uv, int2(N * 3, N * 3), 2, sd + 8u)) * 0.06;
    float r = length(wq - pith);
    float phase = r * max(P.f.y, 2.0) * (0.8 + 0.4 * id);
    float fr = fract(phase);
    float late = smoothstep(0.55, 0.85, fr) * (1.0 - smoothstep(0.9, 1.0, fr));
    float pores = fbm(uv, int2(N * 40, N * 40), 2, sd + 9u);
    float rays = gnoise(float2(atan2(wq.y - pith.y, wq.x - pith.x) * 60.0, r * 4.0), int2(4096, 4096), sd + 11u);
    float3 base = dark ? P.colorB.rgb : P.colorA.rgb;
    base *= 0.78 + 0.44 * id;
    base = mix(base, base * float3(1.08, 0.94, 0.8), id2 * 0.5);              // warm/cool block shift
    float3 lateC = dark ? base * 0.55 : base * float3(0.78, 0.7, 0.6);
    float3 c = mix(base, lateC, late * 0.75);
    c *= 0.94 + pores * 0.16 + rays * 0.04;
    // Glue lines.
    float2 e = min(f, 1.0 - f);
    float glue = 1.0 - smoothstep(0.0, 0.012, min(e.x, e.y));
    c = mix(c, P.colorC.rgb, glue * 0.85);
    // Knife scoring: thin cuts at a few dominant angles, lighter fibers raised on one side.
    float cut = 0.0;
    for (int i = 0; i < 6; i++) {
        float a = (h01u(sd + uint(i) * 19u) - 0.5) * 1.2 + (i % 2 == 0 ? 0.0 : 1.5708);
        int2 fq = int2(3 + i, 150 + i * 30);
        float2 rr = rot2(uv - 0.5, a) + 0.5;
        float n = gnoise(fract(rr) * float2(fq), fq, sd + 40u + uint(i));
        float mask = smoothstep(0.05, 0.4, fbm(uv, int2(3, 3), 3, sd + 60u + uint(i)) + 0.15);
        cut = max(cut, (1.0 - smoothstep(0.0, 0.025, abs(n))) * mask);
    }
    cut *= P.f.z;
    c = mix(c, c * 0.55, cut * 0.6);
    float wet = smoothstep(0.1, 0.55, fbm(uv, int2(2, 2), 4, sd + 70u));     // oiled patches
    c *= 1.0 - wet * 0.08;
    s.albedo = c;
    s.height = 0.55 + late * 0.03 + pores * 0.05 - glue * 0.25 - cut * 0.35;
    s.rough = sat(P.f.w + pores * 0.08 + cut * 0.1 - wet * 0.15 + glue * 0.05);
    s.ao = 1.0 - glue * 0.4 - cut * 0.3;
    s.metal = 0.0;
    return s;
}

// Seasoned cast iron: sand-cast pebble grain under polymerized oil. Thick seasoning is black and
// satin; thin seasoning shows warm grey-brown iron; carbon crust sits in patches.
// colorA thick seasoning, colorB thin seasoning / iron, colorC carbon crust. f.x pebble cells per tile,
// f.y thin-seasoning amount (rubbed areas), f.z carbon crust amount, f.w base roughness.
S seasonedIron(float2 uv, constant RFParams &P) {
    S s = defaults(); uint sd = P.seed;
    int q = max(8, int(P.f.x));
    float4 w1 = worley(uv, int2(q, q), sd + 1u, 0.9);
    float4 w2 = worley(uv, int2(q * 2, q * 2), sd + 2u, 0.9);
    float peb = sqrt(sat(1.0 - w1.x * 1.2)) * 0.6 + sqrt(sat(1.0 - w2.x * 1.2)) * 0.4;
    float n = fbm(uv, int2(3, 3), 5, sd + 3u);
    float thin = smoothstep(-0.1, 0.35, n + (P.f.y - 0.5) * 0.7) * P.f.y;
    thin = sat(thin + smoothstep(0.75, 0.95, peb) * 0.35 * P.f.y);   // pebble tops rub through
    float cn = fbm(uv, int2(5, 5), 5, sd + 4u) + 0.3 * fbm(uv, int2(20, 20), 3, sd + 5u);
    float crust = smoothstep(0.18, 0.4, cn + (P.f.z - 0.5) * 0.5) * P.f.z;
    float mott = fbm(uv, int2(12, 12), 3, sd + 6u);
    float3 c = P.colorA.rgb * (0.9 + 0.22 * mott + peb * 0.3);
    c = mix(c, P.colorB.rgb * (0.85 + 0.3 * mott), thin * 0.8);
    c = mix(c, P.colorC.rgb * (0.8 + 0.4 * w2.z), crust * 0.85);
    s.albedo = c;
    s.metal = sat(thin * 0.55);
    s.rough = sat(P.f.w - peb * 0.08 + thin * 0.12 + crust * 0.3 + mott * 0.05);
    s.height = 0.5 + peb * 0.12 + crust * 0.12 * (0.6 + 0.4 * w1.z);
    s.ao = 1.0 - (1.0 - peb) * 0.12 - crust * 0.1;
    return s;
}

// Thin-film color of stainless oxide by film thickness t (0 clean ... 1 deep blue).
float3 temperColor(float3 base, float t) {
    float3 c = base;
    c = mix(c, float3(0.62, 0.48, 0.2), smoothstep(0.05, 0.25, t));     // straw gold
    c = mix(c, float3(0.42, 0.24, 0.12), smoothstep(0.25, 0.45, t));    // bronze
    c = mix(c, float3(0.3, 0.16, 0.38), smoothstep(0.45, 0.62, t));     // purple
    c = mix(c, float3(0.14, 0.24, 0.55), smoothstep(0.62, 0.8, t));     // blue
    c = mix(c, float3(0.32, 0.45, 0.62), smoothstep(0.85, 1.0, t));     // pale blue
    return c;
}

// Heat-tinted brushed stainless (pan bases and lower walls): spin streaks along U and an oxide band
// across V that peaks at v = f.y (tile fraction), broken up by noise.
// colorA metal, colorB smudge, colorC.a utensil scratches. f.x tint strength (0...1), f.y band center along V, f.z streaks,
// f.w base roughness.
S heatTint(float2 uv, constant RFParams &P) {
    S s = defaults(); uint sd = P.seed;
    float st = gnoise(uv * float2(3, 900), int2(3, 900), sd + 1u) * 0.6 + gnoise(uv * float2(6, 2400), int2(6, 2400), sd + 2u) * 0.4;
    float band = pow(0.5 + 0.5 * cos(6.2831853 * (uv.y - P.f.y)), 12.0);
    float n = fbm(uv, int2(4, 3), 5, sd + 3u);
    float lick = fbm(uv, int2(9, 2), 4, sd + 4u);
    float t = sat(band * P.f.x * (0.85 + n * 0.9 + lick * 0.6));
    float smudge = smoothstep(0.1, 0.5, fbm(uv, int2(3, 3), 4, sd + 5u));
    float3 metal = P.colorA.rgb * (0.94 + st * 0.08 * P.f.z);
    float3 c = mix(metal, temperColor(metal, t), 0.55 + 0.25 * t);
    c = mix(c, P.colorB.rgb, smudge * 0.15);
    // Utensil scratches (colorC.a = amount): short arcs at random angles.
    float scratch = 0.0;
    for (int i = 0; i < 5; i++) {
        float a = h01u(sd + uint(i) * 13u) * 3.14159;
        int2 fr = int2(4 + i * 2, 260);
        float2 r = rot2(uv - 0.5, a) + 0.5;
        float sn = gnoise(fract(r) * float2(fr), fr, sd + 20u + uint(i));
        scratch = max(scratch, (1.0 - smoothstep(0.0, 0.014, abs(sn))) * smoothstep(0.25, 0.6, fbm(uv, int2(3, 3), 3, sd + 50u + uint(i))));
    }
    scratch *= P.colorC.a;
    c *= 1.0 + scratch * 0.14;
    s.albedo = c;
    s.metal = 1.0;
    s.rough = sat(P.f.w + st * 0.05 * P.f.z + t * 0.06 + smudge * 0.08 - scratch * 0.08);
    s.height = 0.5 + st * 0.012 * P.f.z - scratch * 0.06;
    s.ao = 1.0;
    return s;
}
"""#
