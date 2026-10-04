// Sports-ground programs: mown turf with mowing stripes, infield clay, chain-link mesh.

let metalSports = #"""
// ---------------------------------------------------------------- sports grounds
// Mown sports turf seen from above: layered short blades over a dark thatch, with mowing bands.
// colorA dark blade, colorB light blade, colorC thatch and soil. f.x stripe contrast, f.y bands per
// tile along u (integer), f.z checkerboard (1) or plain stripes (0), f.w worn or thin patches.
S turf(float2 uv, constant RFParams &P) {
    S s = defaults(); uint sd = P.seed;
    float N = max(1.0, floor(P.f.y + 0.5));
    float2 g = uv * N; float2 b = floor(g); float2 f = g - b;
    float sx = (fmod(b.x, 2.0) * 2.0 - 1.0) * smoothstep(0.0, 0.035, min(f.x, 1.0 - f.x));
    float sy = (fmod(b.y, 2.0) * 2.0 - 1.0) * smoothstep(0.0, 0.035, min(f.y, 1.0 - f.y));
    float stripe = P.f.z > 0.5 ? sx * sy : sx;
    float macro = fbm(uv, int2(3, 3), 4, sd + 1u);
    float mid = fbm(uv, int2(24, 24), 3, sd + 2u);
    float wear = P.f.w * smoothstep(0.15, 0.45, fbm(uv, int2(4, 4), 4, sd + 3u));
    // Thatch floor: dead clippings and soil, mostly hidden under dense blades.
    float3 thatch = mix(P.colorA.rgb * 0.55, P.colorC.rgb, 0.25 + 0.2 * mid);
    s.albedo = thatch * (0.8 + 0.25 * fbm(uv, int2(600, 600), 2, sd + 4u));
    s.height = 0.15; s.ao = 0.6; s.rough = 0.85;
    // Mowing direction alternates per band; blades lie along it.
    float dirA = (stripe >= 0.0 ? 0.0 : 3.14159265);
    for (int layer = 0; layer < 3; layer++) {
        float cid = 0.0, cid2 = 0.0;
        int fr = 300 + layer * 80;
        float2 off = cellLocal(uv, int2(fr, fr), sd + 30u + uint(layer) * 17u, cid, cid2);
        if (cid2 < wear * (0.9 - 0.2 * float(layer))) continue;
        float ang = dirA + (cid - 0.5) * 1.2;
        float2 q = rot2(off, ang);
        float L = 0.7 + 0.3 * cid2, W = 0.1 + 0.05 * cid;
        float lx = q.x / L;
        if (abs(lx) < 1.0 && abs(q.y) < W * (1.0 - lx * lx)) {
            float t = (lx + 1.0) * 0.5;
            float3 c = mix(P.colorA.rgb, P.colorB.rgb, sat(0.35 + 0.25 * cid2 + 0.2 * macro + 0.15 * float(layer)));
            if (fract(cid * 37.0) < 0.02) c = mix(c, P.colorC.rgb * 1.2, 0.5);   // dry tip
            float rib = 1.0 - abs(q.y) / max(W * (1.0 - lx * lx), 1e-4);
            s.albedo = c * (0.88 + 0.1 * rib + 0.06 * t) * (0.9 + 0.05 * float(layer));
            s.height = 0.35 + 0.15 * float(layer) + 0.1 * rib;
            s.ao = 0.75 + 0.1 * float(layer);
            s.rough = 0.8 - 0.04 * float(layer);
        }
    }
    // Clover and weed rosettes, sparse.
    float4 cl = worley(uv, int2(40, 40), sd + 9u, 1.0);
    if (cl.z < 0.05 && cl.x < 0.18) { s.albedo = mix(s.albedo, P.colorA.rgb * float3(0.8, 1.15, 0.8), 0.6); s.height += 0.05; }
    // Bands: blades bent away from the viewer read light and glossy, toward the viewer dark.
    float k = P.f.x * 0.5 * stripe;
    s.albedo *= 1.0 + k;
    s.albedo = mix(s.albedo, s.albedo * float3(1.05, 1.03, 0.9), max(0.0, stripe) * P.f.x * 0.6);
    s.albedo *= 0.94 + 0.12 * macro;
    s.rough = clamp(s.rough - 0.1 * k, 0.55, 1.0);
    s.albedo = mix(s.albedo, thatch * 1.1, wear * 0.35);
    s.height *= 0.8;
    return s;
}

// Infield skin: clay-sand mix, nail-drag lines along u, calcined clay granules, cleat prints.
// colorA moist clay, colorB dry surface dust, colorC conditioner granules.
// f.x drag lines, f.y cleat prints, f.z moisture, f.w granules.
S infieldClay(float2 uv, constant RFParams &P) {
    S s = defaults(); uint sd = P.seed;
    float big = fbm(uv, int2(4, 4), 4, sd + 1u);
    float mid = fbm(uv, int2(24, 24), 3, sd + 2u);
    float fine = fbm(uv, int2(220, 220), 2, sd + 3u);
    float dry = sat(smoothstep(-0.25, 0.35, big + 0.5 * mid) * (1.0 - P.f.z));
    float3 col = mix(P.colorA.rgb, P.colorB.rgb, dry * 0.85) * (0.9 + 0.18 * mid + 0.08 * fine);
    float h = 0.45 + big * 0.06 + mid * 0.02 + fine * 0.01;
    // Drag mat and nail drag: fine parallel grooves along u, wavering.
    float dv = uv.y + 0.004 * fbm(uv, int2(3, 3), 2, sd + 4u);
    float dn = gnoise(float2(uv.x * 5.0, dv * 260.0), int2(5, 260), sd + 5u);
    float drag = P.f.x * smoothstep(-0.05, 0.4, dn) * (0.6 + 0.4 * smoothstep(-0.3, 0.3, big));
    h += drag * 0.012; col *= 1.0 + drag * 0.05;
    // Calcined clay granules: small dark-red grains on top.
    float4 gr = worley(uv, int2(320, 320), sd + 6u, 1.0);
    if (gr.z < P.f.w && gr.x < 0.32) {
        float r = gr.x / 0.32;
        col = mix(col, P.colorC.rgb * (0.85 + 0.3 * gr.w), smoothstep(1.0, 0.6, r));
        h += sqrt(sat(1.0 - r * r)) * 0.008;
    }
    // Light pebbles from the sand fraction.
    float4 pb = worley(uv, int2(140, 140), sd + 7u, 1.0);
    if (pb.z < 0.05 && pb.x < 0.2) { col = mix(col, P.colorB.rgb * 1.25, 0.7); h += 0.006; }
    // Cleat prints: outsole ovals with stud dimples, in random headings.
    float cid = 0.0, cid2 = 0.0;
    float2 off = cellLocal(uv, int2(6, 6), sd + 8u, cid, cid2);
    if (cid2 < P.f.y) {
        float2 q = rot2(off, cid * 6.2831853);
        float2 e = q / float2(0.42, 0.14);
        float r = length(e);
        if (r < 1.0) {
            float press = smoothstep(1.0, 0.8, r);
            h -= press * 0.012; col = mix(col, P.colorA.rgb * 0.92, press * 0.5);
            float2 st = q / 0.085; float2 sf = st - floor(st) - 0.5;
            float d = length(sf);
            if (d < 0.22 && abs(q.x) < 0.38) { h -= 0.01 * smoothstep(0.22, 0.1, d); col *= 0.9; }
        }
    }
    s.albedo = col; s.height = h; s.rough = mix(0.9, 0.72, (1.0 - dry) * P.f.z) - 0.04 * fine;
    s.ao = mix(0.75, 1.0, smoothstep(0.3, 0.5, h));
    s.height *= 0.85;
    return s;
}

// Chain-link fabric: woven wires forming diamonds, cutout. 2 x 2 diamonds per tile.
// colorA wire (galvanized or vinyl), colorB wire shade. f.x metalness, f.y wire radius (tile fraction),
// f.z roughness, f.w spangle / grime.
S chainLink(float2 uv, constant RFParams &P) {
    S s = defaults(); uint sd = P.seed;
    float w = max(0.006, P.f.y);
    float a = (uv.x + uv.y) * 2.0, b = (uv.x - uv.y) * 2.0;
    float da = abs(fract(a + 0.5) - 0.5) * 0.35355, db = abs(fract(b + 0.5) - 0.5) * 0.35355;
    float d = min(da, db);
    s.alpha = d < w ? 1.0 : 0.0;
    float onA = da < db ? 1.0 : 0.0;
    float r = sat(d / w);
    float prof = sqrt(sat(1.0 - r * r));
    // Over/under at crossings, twisted knuckle along each wire.
    float along = onA > 0.5 ? b : a;
    float over = 0.5 + 0.5 * sin(along * 3.14159265 + (onA > 0.5 ? 0.0 : 3.14159265));
    float twist = 0.5 + 0.5 * sin(along * 3.14159265 * 8.0 + r * 2.0);
    float n = fbm(uv, int2(8, 8), 3, sd + 1u);
    s.albedo = mix(P.colorB.rgb, P.colorA.rgb, 0.45 + 0.55 * prof) * (0.9 + 0.15 * n + 0.06 * twist);
    s.height = 0.2 + 0.5 * prof * (0.6 + 0.4 * over);
    s.rough = clamp(P.f.z + 0.15 * P.f.w * n, 0.15, 1.0);
    s.metal = P.f.x;
    s.ao = mix(0.6, 1.0, prof) * mix(0.8, 1.0, over);
    return s;
}
"""#
