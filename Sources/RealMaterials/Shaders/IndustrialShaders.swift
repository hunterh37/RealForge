// Construction and farm programs: plywood, galvanized, straw, paintedWood, jute.

let metalIndustrial = #"""
// ---------------------------------------------------------------- industrial / farm
// Plywood. f.x 0 = face veneer (rotary-cut softwood, grain along U, f.z = patch amount);
// f.x 1 = edge (f.y plies across V; one tile in V = sheet thickness). colorA earlywood, colorB latewood,
// colorC glue lines and core voids.
S plywood(float2 uv, constant RFParams &P) {
    S s = defaults(); uint sd = P.seed;
    if (P.f.x > 0.5) {
        float plies = max(3.0, floor(P.f.y + 0.5));
        float b = uv.y * plies; float idx = floor(b); float f = b - idx;
        float crossPly = fmod(idx, 2.0);
        float tone = h01(int2(int(idx), 3), sd);
        float streak = fbm(uv, int2(3, 8), 3, sd + 3u);
        float pores = smoothstep(0.3, 0.08, worley(uv, int2(24, 16), sd + 5u, 1.0).x) * crossPly;
        float glue = 1.0 - smoothstep(0.02, 0.09, min(f, 1.0 - f));
        float4 vw = worley(uv, int2(6, 2), sd + 11u, 1.0);
        float voidm = crossPly * step(0.8, vw.z) * smoothstep(0.32, 0.18, vw.x) * smoothstep(0.12, 0.25, f) * smoothstep(0.88, 0.75, f);
        float3 c = mix(P.colorA.rgb, P.colorB.rgb, sat(0.15 + tone * 0.35 + streak * 0.5 + crossPly * 0.2));
        c *= 1.0 - pores * 0.25;
        c = mix(c, P.colorC.rgb, glue * 0.85);
        c = mix(c, P.colorC.rgb * 0.35, voidm);
        s.albedo = c;
        s.height = 0.55 + streak * 0.05 - glue * 0.08 - voidm * 0.4 - pores * 0.05;
        s.rough = 0.82 + crossPly * 0.06; s.ao = 1.0 - voidm * 0.6 - glue * 0.15;
        s.alpha = 1.0; s.metal = 0.0;
        return s;
    }
    // Face: broad cathedral figure from peeling the log, hard-edged latewood bands.
    float warp = fbm(uv, int2(1, 2), 4, sd + 1u) * 1.0 + fbm(uv, int2(3, 5), 3, sd + 2u) * 0.25;
    float figure = uv.y * 22.0 + warp * 9.0;
    float r = fract(figure);
    float late = smoothstep(0.0, 0.04, r) * (1.0 - smoothstep(0.18, 0.5, r));
    float streak = fbm(uv, int2(4, 180), 2, sd + 4u);
    float blotch = fbm(uv, int2(3, 6), 4, sd + 6u);
    // Football patches (oval repairs with straight grain), and small dark knots.
    float cid, cid2;
    float2 off = cellLocal(uv, int2(4, 8), sd + 7u, cid, cid2);
    float pd = length(off / float2(0.2, 0.12));
    float patch = (1.0 - smoothstep(0.92, 1.0, pd)) * step(cid, P.f.z * 0.35);
    float rim = smoothstep(0.85, 0.95, pd) * (1.0 - smoothstep(0.98, 1.06, pd)) * step(cid, P.f.z * 0.35);
    float kid, kid2;
    float2 ko = cellLocal(uv, int2(3, 9), sd + 8u, kid, kid2);
    float kd = length(ko / float2(0.09, 0.06));
    float knot = (1.0 - smoothstep(0.7, 1.0, kd)) * step(0.82, kid) * (1.0 - patch);
    float3 c = mix(P.colorA.rgb, P.colorB.rgb, sat(0.2 + blotch * 0.6 + streak * 0.2));
    c = mix(c, P.colorB.rgb * 0.82, late * 0.75);
    float3 pc = mix(P.colorA.rgb * 1.04, P.colorB.rgb, 0.25 + 0.4 * (0.5 + 0.5 * sin(uv.y * 6.2831853 * 120.0)));
    c = mix(c, pc, patch);
    c = mix(c, P.colorC.rgb, rim * 0.6 + knot * 0.8);
    s.albedo = c;
    s.height = 0.5 - late * 0.05 + streak * 0.04 - rim * 0.15 - knot * 0.06;
    s.rough = 0.74 + late * 0.05 + streak * 0.03;
    s.ao = 1.0 - rim * 0.3;
    s.alpha = 1.0; s.metal = 0.0;
    return s;
}

// Hot-dip galvanized steel: zinc spangle crystals, white rust and dirt with age.
// colorA zinc, colorB white rust, colorC dirt. f.x age, f.y dirt, f.z spangles per tile.
S galvanized(float2 uv, constant RFParams &P) {
    S s = defaults(); uint sd = P.seed;
    int fq = int(max(4.0, P.f.z));
    float4 sp = worley(uv, int2(fq, fq), sd + 1u, 0.9);
    float4 sp2 = worley(uv, int2(fq * 3, fq * 3), sd + 2u, 0.9);
    float cell = sp.z * 0.75 + sp2.z * 0.25;
    float bound = 1.0 - smoothstep(0.0, 0.05, sp.y - sp.x);
    // Dendrite feathering inside each crystal, oriented per cell.
    // Four orientations; integer shears keep it periodic.
    int q = int(sp.w * 4.0);
    float2 fu = q == 0 ? uv : (q == 1 ? uv.yx : (q == 2 ? float2(uv.x + uv.y, uv.x - uv.y) : float2(uv.x - uv.y, uv.x + uv.y)));
    float feather = 0.5 + 0.5 * gnoise(fract(fu) * float2(fq, fq * 14), int2(fq, fq * 14), sd + 9u);
    float age = P.f.x;
    float n = fbm(uv, int2(3, 3), 5, sd + 3u);
    float oxide = smoothstep(0.0, 0.25, n + (age - 0.65) * 0.7) * age;
    float spots = smoothstep(0.3, 0.1, worley(uv, int2(18, 18), sd + 4u, 1.0).x) * age;
    oxide = sat(oxide + spots * 0.5);
    float dirt = smoothstep(-0.05, 0.4, fbm(uv, int2(2, 2), 5, sd + 5u)) * P.f.y;
    float3 zinc = P.colorA.rgb * (0.86 + 0.22 * cell + 0.04 * feather) * (1.0 - bound * 0.08);
    zinc *= 1.0 - age * 0.25;
    float3 c = mix(zinc, P.colorB.rgb * (0.9 + 0.2 * n), oxide * 0.8);
    c = mix(c, P.colorC.rgb, dirt * 0.55);
    s.albedo = c;
    s.metal = sat(1.0 - oxide * 0.85 - dirt * 0.6);
    s.rough = mix(0.22 + 0.22 * cell + 0.05 * feather, 0.62, age * 0.7) + oxide * 0.2 + dirt * 0.15;
    s.rough = sat(s.rough);
    s.height = 0.5 + cell * 0.03 - bound * 0.04 + oxide * 0.05 + spots * 0.04;
    s.ao = 1.0 - dirt * 0.2;
    s.alpha = 1.0;
    return s;
}

// Straw: four layers of round strands running along U, bent by a low-frequency warp.
// colorA golden straw, colorB olive/green stems, colorC grey weathering. f.x weathering,
// f.y green fraction, f.z net wrap amount (white diamond net), f.w > 0.5 lays the top layer diagonally (loose hay).
S straw(float2 uv, constant RFParams &P) {
    S s = defaults(); uint sd = P.seed;
    float best = -1.0; float3 col = P.colorB.rgb * 0.18; float shade = 0.0;
    for (int L = 0; L < 4; L++) {
        uint ls = sd + uint(L) * 37u;
        int N = 70 + L * 16;
        int M = 2 + L;
        float wv = fbm(uv, int2(2, 3), 3, ls + 1u) * 0.05 + fbm(uv, int2(6, 4), 2, ls + 2u) * 0.012;
        float shear = (L == 3 && P.f.w > 0.5) ? 1.0 : 0.0;
        float cy = (uv.y + shear * uv.x + wv) * float(N);
        float rowf = floor(cy); float f = cy - rowf;
        int row = int(rowf);
        float off = h01(wrapc(int2(row, L), int2(N, 4)), ls + 3u);
        float cx = uv.x * float(M) + off; float segf = floor(cx); float fx = cx - segf;
        int2 id = wrapc(int2(int(segf), row), int2(M, N));
        float present = step(L == 0 ? 0.1 : 0.4, h01(id, ls + 4u));
        float width = 0.5 + 0.45 * h01(id, ls + 5u);
        float d = abs(f - 0.5) / (0.5 * width);
        float prof = sqrt(sat(1.0 - d * d)) * present;
        prof *= smoothstep(0.0, 0.06, fx) * smoothstep(1.0, 0.94, fx);
        float hgt = float(L) * 0.16 + prof * 0.3;
        if (prof > 0.02 && hgt > best) {
            best = hgt; shade = prof;
            float t = h01(id, ls + 6u);
            float3 sc = P.colorA.rgb * (0.6 + 0.65 * t) * (0.62 + 0.13 * float(L));
            sc = mix(sc, P.colorB.rgb * (0.8 + 0.4 * t), step(h01(id, ls + 7u), P.f.y));
            float node = smoothstep(0.03, 0.0, abs(fract(fx * 3.0 + t) - 0.5) - 0.47);
            sc *= 1.0 - node * 0.25;
            sc *= 0.86 + 0.22 * fbm(uv, int2(M * 6, N), 2, ls + 8u);
            sc = mix(sc, P.colorC.rgb * (0.85 + 0.3 * t), P.f.x * (0.35 + 0.2 * float(L)));
            col = sc;
        }
    }
    float covered = step(0.0, best);
    float h = covered > 0.5 ? best : -0.1;
    float3 c = col * (0.45 + 0.55 * shade);
    // Net wrap: thin white plastic strands in a diamond lattice.
    float a = fract((uv.x + uv.y) * 10.0), b = fract((uv.x - uv.y) * 10.0);
    float net = max(1.0 - smoothstep(0.0, 0.012, min(a, 1.0 - a)), 1.0 - smoothstep(0.0, 0.012, min(b, 1.0 - b))) * P.f.z;
    c = mix(c, float3(0.62, 0.63, 0.6), net);
    s.albedo = c;
    s.height = 0.25 + h * 0.6 + net * 0.25;
    s.rough = mix(0.62 + (1.0 - shade) * 0.2, 0.9, P.f.x * 0.7);
    s.rough = mix(s.rough, 0.45, net);
    s.ao = covered > 0.5 ? mix(0.55, 1.0, sat(best + 0.2)) : 0.35;
    s.ao = max(s.ao, net);
    s.alpha = 1.0; s.metal = 0.0;
    return s;
}

// Painted boards: weathered grey wood (grain along U) under a chalky paint coat that peels along the grain.
// colorA paint, colorB bare wood, colorC dark grain and cracks. f.x peel, f.y chalking, f.z paint roughness.
S paintedWood(float2 uv, constant RFParams &P) {
    S s = defaults(); uint sd = P.seed;
    float warp = fbm(uv, int2(1, 3), 4, sd + 1u) * 0.9;
    float figure = uv.y * 70.0 + warp * 12.0;
    float r = fract(figure);
    float late = smoothstep(0.0, 0.08, r) * (1.0 - smoothstep(0.08, 0.45, r));
    float streak = fbm(uv, int2(3, 160), 3, sd + 4u);
    float chk = (1.0 - smoothstep(0.0, 0.025, abs(gnoise(uv * float2(4, 60), int2(4, 60), sd + 6u))))
              * smoothstep(0.05, 0.3, fbm(uv, int2(3, 6), 3, sd + 7u));
    float3 wood = mix(P.colorB.rgb, P.colorC.rgb, late * 0.45) * (0.85 + 0.3 * streak);
    wood = mix(wood, P.colorC.rgb * 0.6, chk * 0.7);
    float peelN = fbm(uv, int2(4, 12), 5, sd + 2u) + streak * 0.12 + late * 0.05;
    float t = 0.5 - P.f.x * 0.75;
    float bare = smoothstep(t, t + 0.015, peelN);
    float lip = smoothstep(t - 0.035, t, peelN) * (1.0 - bare);
    float chalk = smoothstep(-0.2, 0.4, fbm(uv, int2(3, 5), 4, sd + 3u)) * P.f.y;
    float brush = fbm(uv, int2(6, 90), 3, sd + 5u);
    // f.w: factory finish (1 = sprayed lacquer, no grain telegraph or checks).
    float clean = sat(P.f.w);
    float3 paint = P.colorA.rgb * (0.9 + 0.1 * clean + (0.12 * brush + 0.06 * streak) * (1.0 - clean * 0.85));
    paint = mix(paint, paint * 1.45 + float3(0.035), chalk * 0.6);
    chk *= 1.0 - clean;
    paint *= 1.0 - chk * 0.35;
    paint = mix(paint, paint * 0.75, lip * 0.5);
    s.albedo = mix(paint, wood, bare);
    float hp = 0.62 - late * 0.03 + streak * 0.03 + brush * 0.02 + lip * 0.06 - chk * 0.12;
    float hw = 0.42 - late * 0.06 + streak * 0.07 - chk * 0.25;
    s.height = mix(hp, hw, bare);
    s.rough = mix(P.f.z + chalk * 0.12 + brush * 0.04, 0.88, bare);
    s.ao = 1.0 - chk * 0.4 - bare * late * 0.15;
    s.alpha = 1.0; s.metal = 0.0;
    return s;
}

// Plain-weave jute (sacking): round warp threads along U, weft along V, slubs, loose fibers, open gaps.
// colorA fiber, colorB gap and shadow, colorC fiber variation. f.y dirt, f.z threads per tile.
S jute(float2 uv, constant RFParams &P) {
    S s = defaults(); uint sd = P.seed;
    int T = int(max(8.0, floor(P.f.z + 0.5)));
    float2 g = uv * float(T); float2 cl = floor(g); float2 f = g - cl;
    int2 ci = wrapc(int2(cl), int2(T, T));
    float over = fmod(cl.x + cl.y + 2.0 * float(T), 2.0) < 0.5 ? 1.0 : 0.0;
    float slubW = 0.6 + 0.3 * fbm(uv, int2(4, T), 3, sd + 1u) + 0.12 * h01(int2(ci.y, 1), sd + 2u);
    float slubF = 0.6 + 0.3 * fbm(uv, int2(T, 4), 3, sd + 3u) + 0.12 * h01(int2(ci.x, 2), sd + 4u);
    float dw = (f.y - 0.5) / (0.5 * slubW), df = (f.x - 0.5) / (0.5 * slubF);
    float pw = sqrt(sat(1.0 - dw * dw)), pf = sqrt(sat(1.0 - df * df));
    float sx = sin(3.14159265 * f.x), sy = sin(3.14159265 * f.y);
    float hw = pw * (0.5 + 0.5 * (over > 0.5 ? sx : 1.0 - sx));
    float hf = pf * (0.5 + 0.5 * (over > 0.5 ? 1.0 - sy : sy));
    float isW = hw >= hf ? 1.0 : 0.0;
    float h = max(hw, hf);
    float fibW = fbm(uv, int2(max(2, T / 4), T * 8), 2, sd + 5u);
    float fibF = fbm(uv, int2(T * 8, max(2, T / 4)), 2, sd + 6u);
    float fib = mix(fibF, fibW, isW);
    float tone = mix(h01(int2(ci.x, 7), sd + 8u), h01(int2(ci.y, 9), sd + 9u), isW);
    float fuzz = smoothstep(0.1, 0.45, fbm(uv, int2(T * 2, T * 2), 3, sd + 10u));
    float dirt = smoothstep(0.0, 0.5, fbm(uv, int2(3, 3), 5, sd + 11u)) * P.f.y;
    float3 fiber = mix(P.colorA.rgb, P.colorC.rgb, tone * 0.6) * (0.82 + 0.4 * fib);
    float cover = smoothstep(0.02, 0.15, h);
    float3 c = mix(P.colorB.rgb, fiber * (0.75 + 0.25 * h), cover);
    c = mix(c, P.colorA.rgb * 0.8, (1.0 - cover) * fuzz * 0.5);
    c = mix(c, c * float3(0.55, 0.5, 0.42), dirt * 0.6);
    s.albedo = c;
    s.height = 0.2 + h * 0.6 + fib * 0.05 + (1.0 - cover) * fuzz * 0.08;
    s.rough = 0.9 + fib * 0.04;
    s.ao = mix(0.4, 1.0, cover * (0.6 + 0.4 * h));
    s.alpha = 1.0; s.metal = 0.0;
    return s;
}
"""#
