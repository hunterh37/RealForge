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
S forestFloor(float2 uv, constant RFParams &P) {
    S s = defaults(); uint sd = P.seed;
    float n = fbm(uv, int2(6, 6), 5, sd + 1u);
    s.albedo = P.colorA.rgb * (0.75 + 0.5 * n);
    s.height = 0.3 + n * 0.2; s.rough = 0.92; s.ao = 0.8;
    // Leaf litter: three overlapping layers of oriented leaf shapes.
    for (int layer = 0; layer < 3; layer++) {
        float cid = 0.0, cid2 = 0.0;
        int fr = 22 + layer * 7;
        float2 off = cellLocal(uv + float2(0.37, 0.11) * float(layer), int2(fr, fr), sd + 10u + uint(layer) * 19u, cid, cid2);
        if (cid > P.f.y) continue;                                   // litter amount
        float2 q = rot2(off, cid2 * 6.2831853);
        float L = 0.42 + 0.25 * cid2;
        float lx = q.x / L;
        float prof = pow(max(0.0, 1.0 - lx * lx), 0.8) * (1.0 - 0.3 * lx) * 0.42 * L;
        if (abs(lx) < 1.0 && abs(q.y) < prof) {
            float yn = q.y / max(prof, 1e-4);
            float3 c = mix(P.colorB.rgb, P.colorC.rgb, cid2);
            c *= 0.8 + 0.4 * h01u(uint(cid * 1e6));
            float vein = 1.0 - smoothstep(0.0, 0.08, abs(yn));
            s.albedo = c * (1.0 + 0.2 * vein); s.height = 0.55 + 0.1 * float(layer) + 0.1 * (1.0 - yn * yn) - vein * 0.04;
            s.rough = 0.75; s.ao = 0.9;
        }
    }
    // Twigs.
    float4 tw = worley(uv, int2(7, 7), sd + 40u, 1.0);
    float2 tq = rot2(uv * 7.0, tw.z * 6.28);
    float twig = (1.0 - smoothstep(0.0, 0.025, abs(fract(tq.y) - 0.5) - 0.0)) * step(tw.x, 0.45) * step(0.75, tw.w);
    s.albedo = mix(s.albedo, float3(0.09, 0.06, 0.04), twig);
    s.height += twig * 0.25;
    // Moss / grass patches.
    float moss = smoothstep(0.0, 0.25, fbm(uv, int2(3, 3), 5, sd + 50u) + (P.f.x - 0.5) * 0.6);
    float mfine = fbm(uv, int2(64, 64), 3, sd + 51u);
    s.albedo = mix(s.albedo, float3(0.045, 0.075, 0.018) * (0.7 + 0.6 * mfine) + float3(0.02, 0.02, 0.0) * n, moss);
    s.height = mix(s.height, 0.62 + 0.15 * mfine, moss);
    s.rough = mix(s.rough, 0.95, moss);
    s.ao = mix(s.ao, 0.85 + 0.15 * mfine, moss);
    return s;
}
"""#
