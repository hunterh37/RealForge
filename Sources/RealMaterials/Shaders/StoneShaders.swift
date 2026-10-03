// Rock and ground programs: rockGranite, forestFloor.

let metalStone = #"""
// ---------------------------------------------------------------- stone / ground
S rockGranite(float2 uv, constant RFParams &P) {
    S s = defaults(); uint sd = P.seed;
    float big = fbm(uv, int2(3, 3), 5, sd + 1u);
    float r = ridged(uv, int2(4, 4), 5, sd + 2u);
    float4 sp = worley(uv, int2(150, 150), sd + 3u, 0.9);
    float grain = smoothstep(0.6, 0.2, sp.x) * (0.5 + 0.5 * smoothstep(-0.2, 0.3, fbm(uv, int2(8, 8), 3, sd + 11u)));
    float3 base = mix(P.colorA.rgb, P.colorB.rgb, smoothstep(-0.3, 0.3, big));
    float3 mineral = sp.z < 0.18 ? float3(0.025, 0.025, 0.028) : (sp.z < 0.30 ? float3(0.42, 0.41, 0.39) : (sp.z < 0.38 ? P.colorC.rgb : base));
    s.albedo = mix(base, mineral, grain * 0.45) * (0.85 + 0.3 * fbm(uv, int2(24, 24), 3, sd + 4u));
    float4 cr = worley(uv + 0.03 * float2(fbm(uv, int2(5, 5), 3, sd + 5u), fbm(uv, int2(5, 5), 3, sd + 6u)), int2(5, 5), sd + 7u, 1.0);
    float crack = (1.0 - smoothstep(0.0, 0.02, cr.y - cr.x)) * smoothstep(0.1, 0.35, fbm(uv, int2(4, 4), 4, sd + 12u));
    float lich = smoothstep(0.25, 0.45, fbm(uv, int2(5, 5), 5, sd + 8u)) * P.f.x;
    float lspots = smoothstep(0.35, 0.2, worley(uv, int2(30, 30), sd + 9u, 1.0).x) * lich;
    s.albedo = mix(s.albedo, float3(0.36, 0.38, 0.27), lich * 0.65);
    s.albedo = mix(s.albedo, float3(0.42, 0.2, 0.05), lspots * 0.5);
    s.albedo *= 1.0 - crack * 0.6;
    s.height = 0.45 + big * 0.25 + r * 0.25 + grain * 0.04 - crack * 0.3 + lich * 0.03;
    s.rough = 0.78 - (sp.z > 0.18 && sp.z < 0.30 ? grain * 0.3 : 0.0) + lich * 0.1;
    s.ao = mix(0.5, 1.0, smoothstep(0.1, 0.7, s.height));
    return s;
}
// Topmost leaf covering p among the 3x3 neighbor cells (leaves overlap cell borders). Returns false on miss.
// o.x: across-leaf coord -1..1, o.y: along-leaf -1 (stem) .. 1 (tip), o.z: cell hash, o.w: second hash.
bool ff_leaf(float2 uv, int2 freq, uint seed, float amount, thread float4 &o) {
    float2 p = uv * float2(freq); int2 c = int2(floor(p));
    float best = -1.0; bool hit = false;
    for (int y = -1; y <= 1; y++) for (int x = -1; x <= 1; x++) {
        int2 cc = c + int2(x, y); int2 w = wrapc(cc, freq);
        float cid = h01(w, seed + 13u), cid2 = h01(w, seed + 29u);
        if (cid > amount) continue;
        float2 d = p - (float2(cc) + float2(h01(w, seed), h01(w, seed + 7u)));
        float2 q = rot2(d, cid2 * 6.2831853);
        float L = 0.45 + 0.3 * h01(w, seed + 31u);
        float lx = q.x / L;
        if (abs(lx) >= 1.0) continue;
        float kind = h01(w, seed + 37u);
        float wd = pow(max(0.0, 1.0 - lx * lx), 0.7) * (1.0 - 0.3 * lx) * (0.34 + 0.16 * kind) * L;
        if (kind < 0.4) wd *= 0.68 + 0.32 * sqrt(abs(cos(lx * 6.0 + kind * 9.0)));   // rounded lobes (oak)
        else wd *= 1.0 - 0.06 * abs(sin(lx * 38.0));                               // serrated
        float yn = q.y / max(wd, 1e-4);
        if (abs(yn) >= 1.0) continue;
        float order = h01(w, seed + 43u);
        if (order > best) { best = order; hit = true; o = float4(yn, lx, cid, cid2 + kind * 0.0); }
    }
    return hit;
}
// Topmost pine needle pair (fascicle) near p. Returns signed distance ratio in o.x (0 center, 1 edge).
bool ff_needle(float2 uv, int2 freq, uint seed, float amount, thread float4 &o) {
    float2 p = uv * float2(freq); int2 c = int2(floor(p));
    float best = -1.0; bool hit = false;
    for (int y = -1; y <= 1; y++) for (int x = -1; x <= 1; x++) {
        int2 cc = c + int2(x, y); int2 w = wrapc(cc, freq);
        float cid = h01(w, seed + 13u);
        if (cid > amount) continue;
        float2 b = float2(cc) + float2(h01(w, seed), h01(w, seed + 7u));
        float a = h01(w, seed + 29u) * 6.2831853;
        float L = 0.75 + 0.45 * h01(w, seed + 31u);
        for (int k = 0; k < 2; k++) {
            float ak = a + (k == 0 ? 0.0 : 0.12 + 0.25 * h01(w, seed + 41u));
            float2 dir = float2(cos(ak), sin(ak));
            float2 d = p - b; float t = clamp(dot(d, dir), 0.0, L);
            float2 perp = d - dir * t;
            perp -= float2(-dir.y, dir.x) * (t * t / L) * 0.08;                  // slight curve
            float r = length(perp) / 0.028;
            float order = h01(w, seed + 43u) + float(k) * 0.01;
            if (r < 1.0 && order > best) { best = order; hit = true; o = float4(r, t / L, cid, h01(w, seed + 47u)); }
        }
    }
    return hit;
}
S forestFloor(float2 uv, constant RFParams &P) {
    S s = defaults(); uint sd = P.seed;
    float n = fbm(uv, int2(6, 6), 5, sd + 1u);
    float grit = fbm(uv, int2(160, 160), 2, sd + 2u);
    s.albedo = P.colorA.rgb * (0.7 + 0.5 * n + 0.25 * grit);
    s.height = 0.2 + n * 0.1 + grit * 0.02; s.rough = 0.92; s.ao = 0.5;
    float crumbs = smoothstep(0.6, 0.25, worley(uv, int2(90, 90), sd + 3u, 1.0).x);
    s.albedo *= 1.0 - crumbs * 0.25; s.height += crumbs * 0.02;
    int top = -1;
    // Leaf litter: four overlapping layers, upper layers sparser.
    for (int layer = 0; layer < 4; layer++) {
        float4 o;
        int fr = 16 + layer * 5;
        float amt = P.f.y * (1.0 - 0.15 * float(layer));
        if (!ff_leaf(uv + float2(0.37, 0.11) * float(layer), int2(fr, fr), sd + 10u + uint(layer) * 19u, amt, o)) continue;
        float yn = o.x, lx = o.y, cid = o.z, cid2 = o.w;
        float hole = (cid2 > 0.82) ? smoothstep(0.15, 0.3, gnoise(uv * 300.0, int2(300, 300), sd + 60u + uint(layer))) : 0.0;
        if (hole > 0.5 && abs(yn) > 0.12) continue;                                  // skeletonized patches
        float t = h01u(uint(cid * 1e6) + 5u);
        float3 c = t < 0.4 ? P.colorB.rgb : (t < 0.6 ? P.colorC.rgb : (t < 0.88 ? P.colorB.rgb * 0.55 : P.colorB.rgb * float3(1.12, 0.85, 0.75)));
        c = mix(c, P.colorA.rgb * 1.6, 0.25 * (3.0 - float(layer)) / 3.0);          // lower layers decayed
        c *= 0.8 + 0.4 * h01u(uint(cid * 1e6) + 9u);
        float spots = smoothstep(0.1, 0.35, fbm(uv, int2(120, 120), 2, sd + 70u + uint(layer)));
        c *= 1.0 - spots * 0.35 * cid2;
        float mid = 1.0 - smoothstep(0.0, 0.07, abs(yn));
        float side = 1.0 - smoothstep(0.0, 0.08, abs(fract(lx * 3.5 - abs(yn) * 1.2) - 0.5) - 0.42);
        c *= 1.0 + 0.18 * mid + 0.06 * side;
        c *= 1.0 - 0.25 * smoothstep(0.75, 1.0, abs(yn));                            // curled, darker rims
        c *= 0.85 + 0.3 * saturate(0.5 + 0.5 * lx * (cid - 0.5) * 2.0 + 0.3 * yn * (cid2 - 0.5));
        s.albedo = c;
        float curl = 0.03 + 0.05 * cid2;
        s.height = 0.4 + 0.07 * float(layer) + curl * yn * yn + 0.02 * lx * (cid - 0.5) - mid * 0.006 + side * 0.002;
        s.rough = 0.72 + 0.12 * t;
        top = layer;
    }
    // Pine needles (knob z), above or between leaves.
    for (int layer = 0; layer < 8 && P.f.z > 0.0; layer++) {
        float4 o;
        if (!ff_needle(uv + float2(0.21, 0.53) * float(layer), int2(52, 52), sd + 80u + uint(layer) * 23u, P.f.z * 0.9, o)) continue;
        float nh = 0.36 + 0.035 * float(layer) + 0.012 * sqrt(max(0.0, 1.0 - o.x * o.x));
        if (nh < s.height) continue;
        float3 c = mix(P.colorB.rgb, P.colorC.rgb, o.w * o.w) * (0.55 + 0.45 * h01u(uint(o.z * 1e6) + 3u)) * (0.7 + 0.05 * float(layer));
        c *= 0.85 + 0.15 * sqrt(max(0.0, 1.0 - o.x * o.x));
        s.albedo = c; s.height = nh; s.rough = 0.62; top = max(top, layer / 2);
    }
    s.ao = top < 0 ? 0.5 : 0.62 + 0.1 * float(top);
    // Twigs.
    float4 tw = worley(uv, int2(7, 7), sd + 40u, 1.0);
    float2 tq = rot2(uv * 7.0, tw.z * 6.28);
    float tw_d = abs(fract(tq.y) - 0.5);
    float twig = (1.0 - smoothstep(0.012, 0.022, tw_d)) * step(tw.x, 0.45) * step(0.72, tw.w);
    s.albedo = mix(s.albedo, float3(0.075, 0.055, 0.04) * (0.8 + 0.5 * fbm(uv, int2(64, 64), 2, sd + 41u)), twig);
    s.height = mix(s.height, 0.75 + 0.02 * sqrt(max(0.0, 1.0 - tw_d * tw_d / 0.0005)), twig);
    s.ao = mix(s.ao, 0.95, twig); s.rough = mix(s.rough, 0.85, twig);
    // Moss / grass patches.
    float moss = smoothstep(0.0, 0.25, fbm(uv, int2(3, 3), 5, sd + 50u) + (P.f.x - 0.5) * 0.6);
    float mfine = fbm(uv, int2(64, 64), 3, sd + 51u);
    float mtuft = fbm(uv, int2(256, 256), 2, sd + 52u);
    s.albedo = mix(s.albedo, float3(0.045, 0.075, 0.018) * (0.65 + 0.6 * mfine + 0.3 * mtuft) + float3(0.02, 0.02, 0.0) * n, moss);
    s.height = mix(s.height, 0.62 + 0.12 * mfine + 0.03 * mtuft, moss);
    s.rough = mix(s.rough, 0.95, moss);
    s.ao = mix(s.ao, 0.8 + 0.2 * mfine, moss);
    return s;
}
"""#
