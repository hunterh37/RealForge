// Landscaping hardscape programs: 90-degree herringbone clay/concrete pavers and shredded bark mulch.

let metalLandscaping = #"""
// ---------------------------------------------------------------- landscaping
// 90-degree herringbone of 1 x 2 unit pavers. colorA paver, colorB second paver tone (blend by hash),
// colorC joint sand. f.x units per tile (multiple of 4; a unit is the paver width), f.y tone variation,
// f.z weathering and edge dirt, f.w joint width (unit fraction).
S paverHerringbone(float2 uv, constant RFParams &P) {
    S s = defaults(); uint sd = P.seed;
    int N = max(4, (int(P.f.x) / 4) * 4);
    float2 g = uv * float(N);
    int i = int(floor(g.x)), j = int(floor(g.y));
    int d = i - j;
    int sIdx = (d >= 0) ? d / 4 : -((-d + 3) / 4);
    int r = d - 4 * sIdx;
    float2 lo, hi; bool vert;
    if (r <= 1) { int t = j; lo = float2(t + 4 * sIdx, t); hi = lo + float2(2, 1); vert = false; }
    else { int t = (r == 3) ? j - 1 : j - 2; lo = float2(i, t + 1); hi = lo + float2(1, 2); vert = true; }
    int2 bid = wrapc(int2(int(lo.x), int(lo.y)), int2(N, N));
    float id = h01(bid, sd + (vert ? 11u : 3u));
    float id2 = h01(bid, sd + (vert ? 12u : 4u));
    float2 c = (lo + hi) * 0.5, hlf = (hi - lo) * 0.5;
    float2 p = g - c;
    float jw = max(P.f.w, 2.0 / float(P.size) * float(N)) * 0.5;
    float rc = 0.06;
    float2 q = abs(p) - (hlf - jw - rc);
    float sd_ = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - rc;   // < 0 inside the paver
    sd_ += 0.012 * fbm(uv, int2(N * 6, N * 6), 2, sd + 5u);
    float e = -sd_;
    float joint = 1.0 - smoothstep(-0.01, 0.01, e);
    float bevel = 0.07;
    float rim = sat(e / bevel);
    float fine = fbm(uv, int2(N * 12, N * 12), 3, sd + 6u);
    float4 ag = worley(uv, int2(N * 24, N * 24), sd + 7u, 1.0);
    float agg = (1.0 - smoothstep(0.1, 0.35, ag.x)) * (ag.z - 0.5);
    float stain = smoothstep(0.05, 0.5, fbm(uv, int2(2, 2), 5, sd + 8u)) * P.f.z;
    float edgeDirt = (1.0 - smoothstep(0.0, 0.18, e)) * P.f.z;
    float3 base = mix(P.colorA.rgb, P.colorB.rgb, smoothstep(0.35, 0.75, id));
    float3 col = base * (1.0 + (id2 - 0.5) * P.f.y * 0.5 + agg * 0.2 + fine * 0.1);
    col = mix(col, col * 0.55, sat(stain * 0.35 + edgeDirt * 0.45));
    col = mix(col, col * 0.8, (1.0 - rim) * (1.0 - joint));
    float sandN = gnoise(uv * float(N * 40), int2(N * 40, N * 40), sd + 9u);
    float moss = smoothstep(0.1, 0.5, fbm(uv, int2(4, 4), 4, sd + 10u)) * P.f.z;
    float3 sand = mix(P.colorC.rgb * (0.85 + sandN * 0.3), float3(0.06, 0.08, 0.03), moss * 0.6);
    col = mix(col, sand, joint);
    s.albedo = col;
    float2 tilt = float2(h01(bid, sd + 13u), h01(bid, sd + 14u)) - 0.5;
    float top = 0.62 + dot(p, tilt) * 0.015 + fine * 0.02;
    s.height = mix(top * sqrt(rim) + 0.3 * (1.0 - sqrt(rim)), 0.25 + sandN * 0.03, joint);
    s.rough = sat(0.82 + fine * 0.05 + joint * 0.1 - stain * 0.05);
    s.ao = 1.0 - joint * 0.45 - (1.0 - rim) * 0.15;
    s.metal = 0.0; s.alpha = 1.0;
    return s;
}

// Shredded hardwood bark mulch. colorA chip, colorB shadow between chips, colorC pale fibre / sun-bleached.
// f.x chips per tile (layer 1), f.y bleach amount, f.z roughness, f.w moisture (darkens, glossier).
S barkMulch(float2 uv, constant RFParams &P) {
    S s = defaults(); uint sd = P.seed;
    int F = max(4, int(P.f.x));
    float h = 0.0; float3 col = P.colorB.rgb; float ao = 0.55; float best = -1.0;
    for (int L = 0; L < 4; L++) {
        int f = F + L * (F / 3);
        uint ls = sd + uint(L) * 97u;
        for (int k = 0; k < 2; k++) {
            float cid, cid2;
            float2 uvo = uv + float2(0.5 / float(f) * float(k), 0.37 / float(f) * float(k));
            float2 off = cellLocal(uvo, int2(f, f), ls + uint(k) * 31u, cid, cid2);
            float ang = cid * 6.2831;
            float2 lp = rot2(off, ang);
            float len = 0.55 + 0.6 * cid2, wid = 0.13 + 0.14 * fract(cid * 7.3);
            float2 qq = abs(lp) / float2(len, wid);
            float m = 1.0 - max(qq.x, qq.y * qq.y);
            m += 0.12 * gnoise(uv * float(f * 8), int2(f * 8, f * 8), ls + 3u);
            if (m <= 0.0) continue;
            float layerH = float(L) * 0.12 + 0.2 * cid2 + sqrt(sat(m * 3.0)) * 0.25;
            if (layerH > best) {
                best = layerH;
                float fib = gnoise(float2(lp.x * 3.0, lp.y * 40.0) + cid * 17.0, int2(64, 64), ls + 5u);
                float3 c = P.colorA.rgb * (0.7 + 0.6 * fract(cid2 * 5.1));
                c = mix(c, P.colorC.rgb, sat(fract(cid * 13.7) * P.f.y * 1.4 - 0.2 + fib * 0.3));
                c *= 0.85 + 0.3 * fib;
                col = c; h = layerH + fib * 0.03;
                ao = 0.6 + 0.4 * sat(layerH / 0.6);
            }
        }
    }
    float wet = P.f.w;
    col *= 1.0 - wet * 0.35;
    s.albedo = col; s.height = sat(h);
    s.rough = sat(P.f.z - wet * 0.25 + (1.0 - ao) * 0.1);
    s.ao = ao;
    s.metal = 0.0; s.alpha = 1.0;
    return s;
}
"""#
