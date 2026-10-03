// Rock and ground programs: rockGranite, forestFloor. More rock programs in RockShaders.swift.

let metalStone = #"""
// ---------------------------------------------------------------- stone / ground
// Crystalline rock. colorA base, colorB light feldspar, colorC accent mineral (pink feldspar, iron).
// knobs: x lichen, y pits (solution pits, vesicles), z grain suppression (0 granite ... 1 fine-grained),
// w rain streaks.
S rockGranite(float2 uv, constant RFParams &P) {
    S s = defaults(); uint sd = P.seed;
    float2 q = uv + 0.035 * float2(fbm(uv, int2(4, 4), 3, sd + 20u), fbm(uv, int2(4, 4), 3, sd + 21u));
    float big = fbm(q, int2(3, 3), 5, sd + 1u);
    float r = ridged(q, int2(4, 4), 5, sd + 2u);
    float grainAmt = 1.0 - sat(P.f.z);
    // Interlocking crystals: every Worley cell is one grain, classed by its hash.
    float4 cx = worley(q, int2(110, 110), sd + 3u, 0.95);
    float4 cf = worley(q, int2(230, 230), sd + 13u, 0.95);
    float3 base = mix(P.colorA.rgb, P.colorB.rgb, smoothstep(-0.35, 0.35, big));
    float3 grainCol = cx.z < 0.16 ? float3(0.022, 0.022, 0.025)                                  // biotite, hornblende
                    : (cx.z < 0.38 ? float3(0.30, 0.30, 0.29)                                    // quartz (glassy grey)
                    : (cx.z < 0.50 ? P.colorC.rgb : P.colorB.rgb * (0.9 + 0.25 * cx.w)));        // feldspars
    float3 fineCol = cf.z < 0.2 ? float3(0.03) : (cf.z < 0.5 ? base * 0.85 : base * 1.12);
    float boundary = 1.0 - smoothstep(0.0, 0.06, cx.y - cx.x);
    float3 alb = mix(base, grainCol, 0.38 * grainAmt);
    alb = mix(alb, fineCol, 0.35);
    alb *= (1.0 - 0.18 * boundary * grainAmt) * (0.86 + 0.28 * fbm(q, int2(24, 24), 3, sd + 4u));
    // Fracture network.
    float4 cr = worley(q + 0.04 * float2(fbm(uv, int2(5, 5), 3, sd + 5u), fbm(uv, int2(5, 5), 3, sd + 6u)), int2(5, 5), sd + 7u, 1.0);
    float crack = (1.0 - smoothstep(0.0, 0.018, cr.y - cr.x)) * smoothstep(0.05, 0.3, fbm(uv, int2(4, 4), 4, sd + 12u));
    float4 cr2 = worley(q, int2(13, 13), sd + 17u, 1.0);
    float hair = (1.0 - smoothstep(0.0, 0.012, cr2.y - cr2.x)) * smoothstep(0.1, 0.3, fbm(uv, int2(6, 6), 3, sd + 18u));
    // Pits: solution pits in limestone, gas vesicles in basalt.
    float4 pw = worley(q, int2(48, 48), sd + 22u, 0.9);
    float pit = (1.0 - smoothstep(0.08, 0.3, pw.x * (0.7 + 0.6 * pw.w))) * step(pw.z, 0.55) * sat(P.f.y);
    // Rain streaks: noise stretched along v (down the faces in triplanar side projections).
    float streak = smoothstep(0.05, 0.35, fbm(uv, int2(28, 3), 4, sd + 30u)) * sat(P.f.w);
    alb *= 1.0 - 0.3 * streak;
    // Lichen: crusty rosettes, grey-green with occasional orange Xanthoria.
    float lmask = smoothstep(0.15, 0.45, fbm(uv, int2(5, 5), 5, sd + 8u) + 0.25 * (P.f.x - 0.5)) * sat(P.f.x * 1.5);
    float4 lw = worley(uv, int2(26, 26), sd + 9u, 1.0);
    float rosette = smoothstep(0.55, 0.3, lw.x) * lmask;
    float crust = rosette * (0.7 + 0.3 * fbm(uv, int2(96, 96), 2, sd + 10u));
    float3 lichCol = lw.z < 0.18 ? float3(0.48, 0.28, 0.04) : (lw.z < 0.55 ? float3(0.40, 0.42, 0.34) : float3(0.30, 0.33, 0.22));
    alb = mix(alb, lichCol, crust * 0.8);
    alb *= 1.0 - crack * 0.65 - hair * 0.25 - pit * 0.45;
    s.albedo = alb;
    s.height = 0.45 + big * 0.22 + r * 0.22 + (0.03 * cx.z - 0.03 * boundary) * grainAmt - crack * 0.3 - hair * 0.06 - pit * 0.25 + crust * 0.04;
    float quartz = (cx.z >= 0.16 && cx.z < 0.38) ? grainAmt * (1.0 - boundary) : 0.0;
    s.rough = clamp(0.8 - quartz * 0.3 + crust * 0.12 + streak * 0.05, 0.3, 1.0);
    s.ao = mix(0.45, 1.0, smoothstep(0.1, 0.65, s.height)) * (1.0 - 0.4 * crack);
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
