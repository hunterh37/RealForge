// Ground programs: gravel, sand, mud, snow, cobblestone, dirtPath. forestFloor lives in StoneShaders.swift.

let metalGround = #"""
// ---------------------------------------------------------------- ground
// One stone per Voronoi cell. h: stone top height in tile units (0 = outside the stone), rr: radial
// position 0 (center) to 1 (rim), edge: distance to the cell border, id/id2: per-stone hashes.
struct GStone { float h; float rr; float edge; float id; float id2; };

GStone gr_stones(float2 uv, int2 freq, uint seed, float fill, float angular) {
    float2 p = uv * float2(freq); float2 fl = floor(p); int2 c = int2(fl);
    float f1 = 9.0, f2 = 9.0; float2 d1 = 0.0, d2 = 0.0; int2 w1 = int2(0);
    for (int y = -1; y <= 1; y++) for (int x = -1; x <= 1; x++) {
        int2 cc = c + int2(x, y); int2 w = wrapc(cc, freq);
        float2 j = 0.12 + 0.76 * float2(h01(w, seed), h01(w, seed + 7u));
        float2 d = float2(cc) + j - p; float l = length(d);
        if (l < f1) { f2 = f1; d2 = d1; f1 = l; d1 = d; w1 = w; } else if (l < f2) { f2 = l; d2 = d; }
    }
    GStone g; g.id = h01(w1, seed + 13u); g.id2 = h01(w1, seed + 29u);
    float2 dd = d2 - d1;
    g.edge = dot(0.5 * (d1 + d2), dd / max(length(dd), 1e-5));
    // Rounded: rotated ellipse with a lumpy outline.
    float2 q = rot2(-d1, g.id2 * 6.2831853);
    float el = 0.62 + 0.38 * h01(w1, seed + 41u);
    q.y /= el;
    float ang = atan2(q.y, q.x);
    float rad = fill * (0.36 + 0.14 * g.id) * (1.0 + 0.08 * sin(3.0 * ang + g.id * 9.0) + 0.05 * sin(5.0 * ang + g.id2 * 7.0));
    float rr = length(q) / rad;
    float dome = sqrt(max(0.0, 1.0 - rr * rr));
    // Angular: Voronoi cell shrunk by a gap, chamfered rim, two tilted fracture facets.
    float gap = mix(0.16, 0.06, fill);
    float e = g.edge - gap;
    float2 n1 = float2(cos(g.id * 6.28), sin(g.id * 6.28)), n2 = float2(cos(g.id2 * 6.28 + 2.0), sin(g.id2 * 6.28 + 2.0));
    float facet = min(min(e * 4.5, 0.9 + dot(-d1, n1) * 0.7), 0.95 + dot(-d1, n2) * 0.6);
    float angH = e > 0.0 ? max(facet, 0.0) : 0.0;
    float rH = rr < 1.0 ? dome : 0.0;
    g.h = mix(rH, angH, angular) * (0.7 + 0.6 * h01(w1, seed + 53u)) / float(freq.x);
    g.rr = mix(min(rr, 1.0), 1.0 - saturate(e * 4.0), angular);
    return g;
}

// Stone color from three tones plus occasional dark basalt and white quartz pieces.
float3 gr_stoneColor(float id, float id2, float3 a, float3 b, float3 c) {
    float3 col = mix(a, b, id);
    col = mix(col, c, smoothstep(0.75, 1.0, id2) * 0.8);
    col *= 0.8 + 0.4 * fract(id * 7.31 + id2 * 3.17);
    if (id2 < 0.025) col = col * 0.35;
    else if (id2 > 0.985) col = mix(col, float3(0.6, 0.58, 0.55), 0.6);
    return col;
}

// Gravel and pebbles. colorA/B stone tones, colorC fines. knobs: x angular (0 river pebbles, 1 crushed),
// y stone size (1 = 15 to 40 mm at a 1 m tile), z fines between stones, w raked furrows.
S gravel(float2 uv, constant RFParams &P) {
    S s = defaults(); uint sd = P.seed;
    float size = max(P.f.y, 0.2);
    float n = fbm(uv, int2(6, 6), 4, sd + 1u);
    float fines = P.f.z;
    float rake = 0.0;
    if (P.f.w > 0.0) {
        float ph = uv.y * 24.0 + fbm(uv, int2(2, 2), 3, sd + 2u) * 1.5;
        rake = (0.5 + 0.5 * cos(ph * 6.2831853)) * P.f.w;
    }
    float base = 0.004 + 0.006 * n + 0.008 * fines + rake * 0.02;
    float grit = fbm(uv, int2(256, 256), 2, sd + 3u);
    s.albedo = P.colorC.rgb * (0.8 + 0.5 * n + 0.25 * grit);
    s.height = base + grit * 0.0015; s.rough = 0.92; s.ao = 0.55;
    float top = 0.0;
    int f0 = max(4, int(26.0 / size));
    for (int layer = 0; layer < 4; layer++) {
        int fr = int(float(f0) * (layer == 0 ? 1.0 : (layer == 1 ? 1.45 : (layer == 2 ? 2.1 : 3.3))));
        GStone g = gr_stones(uv + float2(0.173, 0.411) * float(layer), int2(fr, fr), sd + 100u + uint(layer) * 37u, 1.25, P.f.x);
        if (g.h <= 0.0) continue;
        float sink = (0.35 + 0.3 * h01u(uint(g.id * 1e6) + 3u)) / float(fr);   // bedding depth
        float hh = g.h - sink * 0.5 + rake * 0.01;
        if (hh <= s.height) continue;
        float3 col = gr_stoneColor(g.id, g.id2, P.colorA.rgb, P.colorB.rgb, P.colorC.rgb);
        float sp = fbm(uv, int2(96, 96), 3, sd + 7u + uint(layer));
        col *= 0.85 + 0.35 * sp;
        col *= mix(0.62, 1.0, sqrt(saturate(1.0 - g.rr)));                   // self-shading toward the rim
        float bury = smoothstep(0.0, 0.012, hh - base);
        col = mix(P.colorC.rgb * (0.8 + 0.4 * n), col, mix(1.0, bury, fines));
        s.albedo = col;
        s.height = hh + sp * 0.0015;
        s.rough = mix(0.62, 0.8, P.f.x) - 0.08 * sp + (1.0 - bury) * fines * 0.15;
        s.ao = mix(0.55, 1.0, sqrt(saturate(1.0 - g.rr)));
        top = 1.0;
    }
    s.ao *= mix(0.75, 1.0, smoothstep(0.0, 0.02, s.height));
    s.height *= 22.0;
    return s;
}

// Wind-rippled sand. colorA sand, colorB heavy-mineral trough tint, colorC shell fragments.
// knobs: x ripple strength, y wetness, z shell and grit amount, w ripples per tile (0 = 30).
S sand(float2 uv, constant RFParams &P) {
    S s = defaults(); uint sd = P.seed;
    float R = P.f.w > 0.0 ? floor(P.f.w) : 30.0;
    float warp = fbm(uv, int2(3, 3), 3, sd + 1u) * 2.2 + fbm(uv, int2(9, 9), 2, sd + 2u) * 0.35;
    float ph = uv.x * R + uv.y * 3.0 + warp;
    float f = fract(ph);
    float rip = f < 0.72 ? smoothstep(0.0, 0.72, f) : 1.0 - smoothstep(0.72, 1.0, f);
    float amp = P.f.x * smoothstep(-0.35, 0.2, fbm(uv, int2(4, 4), 3, sd + 3u));
    float und = fbm(uv, int2(2, 2), 4, sd + 4u);
    float grain = fbm(uv, int2(384, 384), 2, sd + 5u);
    int2 gc = int2(floor(uv * 1024.0));
    float gh = h01(wrapc(gc, int2(1024, 1024)), sd + 6u);
    float3 col = P.colorA.rgb * (0.9 + 0.2 * und);
    col = mix(col, P.colorB.rgb, (1.0 - rip) * amp * 0.55);
    col *= 0.92 + 0.16 * grain;
    if (gh < 0.05) col *= 0.55; else if (gh > 0.97) col = mix(col, float3(0.8, 0.78, 0.74), 0.6);
    s.albedo = col;
    s.height = 0.5 + und * 0.25 + rip * amp * 0.12 + grain * 0.012;
    s.rough = 0.88 - 0.05 * grain;
    // Sparkle: a few quartz and mica facets catch the sun.
    if (h01(wrapc(gc, int2(1024, 1024)), sd + 8u) > 0.992) { s.rough = 0.18; s.albedo *= 1.15; }
    s.ao = mix(0.82, 1.0, rip * amp + (1.0 - amp));
    // Shell fragments and grit.
    float cid = 0.0, cid2 = 0.0;
    float2 off = cellLocal(uv, int2(40, 40), sd + 9u, cid, cid2);
    if (cid < P.f.z * 0.5) {
        float2 q = rot2(off, cid2 * 6.28); q.y /= 0.55;
        float r = length(q) / (0.12 + 0.12 * cid2);
        if (r < 1.0) {
            s.albedo = mix(P.colorC.rgb, P.colorA.rgb, 0.5 + 0.3 * cid2) * (0.85 + 0.3 * h01u(uint(cid * 1e6)));
            s.height += 0.02 * sqrt(1.0 - r * r); s.rough = 0.55; s.ao = 1.0;
        }
    }
    float wet = P.f.y;
    s.albedo *= 1.0 - 0.45 * wet;
    s.rough = mix(s.rough, 0.42, wet);
    s.height *= 0.5;
    return s;
}

// Wet mud with standing water in low areas. colorA wet mud, colorB drier crust, colorC straw and grit.
// knobs: x water level (0 none, 1 flooded), y dryness of high ground, z boot prints, w tyre ruts.
S mud(float2 uv, constant RFParams &P) {
    S s = defaults(); uint sd = P.seed;
    float big = fbm(uv, int2(3, 3), 5, sd + 1u);
    float mid = fbm(uv, int2(14, 14), 3, sd + 2u);
    float fine = fbm(uv, int2(96, 96), 2, sd + 3u);
    float4 cl = worley(uv, int2(22, 22), sd + 4u, 1.0);
    float clod = (1.0 - smoothstep(0.0, 0.7, cl.x)) * 0.05;
    float pits = smoothstep(0.25, 0.0, worley(uv, int2(70, 70), sd + 15u, 1.0).x);
    float h = 0.5 + big * 0.5 + mid * 0.16 + fine * 0.05 + clod * 1.6 - pits * 0.02;
    // Tyre ruts along U.
    if (P.f.w > 0.0) {
        float v = uv.y * 2.0 + fbm(uv, int2(2, 2), 2, sd + 5u) * 0.15;
        float fv = fract(v);
        float rut = smoothstep(0.1, 0.0, abs(fv - 0.3)) + smoothstep(0.1, 0.0, abs(fv - 0.7));
        float tread = 0.5 + 0.5 * sin(uv.x * 6.2831853 * 160.0);
        h -= P.f.w * rut * (0.18 + 0.02 * tread);
        float berm = smoothstep(0.17, 0.11, abs(fv - 0.3)) + smoothstep(0.17, 0.11, abs(fv - 0.7));
        h += P.f.w * 0.05 * (berm - rut);
    }
    // Boot prints: sole and heel ovals with tread bars.
    if (P.f.z > 0.0) {
        float cid = 0.0, cid2 = 0.0;
        float2 off = cellLocal(uv, int2(12, 12), sd + 6u, cid, cid2);
        if (cid < P.f.z) {
            float2 q = rot2(off, cid2 * 6.2831853) / float2(0.165, 0.42);   // ~28 x 11 cm at a 4 m tile
            float ls = length((q - float2(0.0, 0.3)) / float2(0.95, 0.68));
            float lh = length((q - float2(0.0, -0.66)) / float2(0.8, 0.32));
            float ins = max(1.0 - smoothstep(0.85, 1.0, ls), 1.0 - smoothstep(0.85, 1.0, lh));
            float lug = step(0.45, fract(q.y * 5.0 + 0.2)) * step(abs(q.x), 0.7);
            h -= ins * (0.1 + 0.035 * lug);
            float lm = min(ls, lh);
            h += 0.035 * (smoothstep(1.0, 1.12, lm) - smoothstep(1.12, 1.5, lm));
        }
    }
    float dry = smoothstep(0.45, 0.85, h) * P.f.y;
    float4 cr = worley(uv + 0.02 * float2(mid, fine), int2(10, 10), sd + 7u, 1.0);
    float crack = (1.0 - smoothstep(0.0, 0.035, cr.y - cr.x)) * dry;
    float3 col = mix(P.colorA.rgb, P.colorB.rgb, dry) * (0.8 + 0.4 * mid + 0.25 * fine) * (1.0 - pits * 0.15);
    col *= 1.0 - crack * 0.5;
    s.albedo = col;
    s.height = h - crack * 0.06;
    s.rough = mix(0.6, 0.9, dry) - 0.08 * fine;
    s.ao = mix(0.7, 1.0, smoothstep(0.2, 0.7, h)) * (1.0 - crack * 0.4);
    // Straw bits and grit.
    float4 tw = worley(uv, int2(18, 18), sd + 8u, 1.0);
    float2 tq = rot2(uv * 18.0, tw.z * 6.28);
    float straw = (1.0 - smoothstep(0.0, 0.03, abs(fract(tq.y) - 0.5))) * step(tw.x, 0.35) * step(0.82, tw.w);
    s.albedo = mix(s.albedo, P.colorC.rgb * (0.6 + 0.4 * tw.z), straw * 0.6 * step(0.5, tw.z));
    s.height += straw * 0.02;
    // Standing water below the level, wet sheen band above it.
    float level = P.f.x >= 0.99 ? 9.0 : mix(0.28, 0.72, P.f.x);
    if (P.f.x > 0.0 && h < level) {
        float depth = saturate((level - h) * 6.0);
        float rip = gnoise(uv * 48.0, int2(48, 48), sd + 9u) * 0.002;
        s.albedo = P.colorA.rgb * mix(0.55, 0.3, depth);
        s.height = level + rip;
        s.rough = 0.04; s.ao = 1.0;
    } else if (P.f.x > 0.0) {
        float wetb = 1.0 - smoothstep(0.0, 0.06, h - level);
        s.albedo *= 1.0 - 0.3 * wetb;
        s.rough = mix(s.rough, 0.15, wetb);
    }
    s.height *= 0.6;
    return s;
}

// Wind-packed snow with sastrugi and ice-crystal glints. colorA snow, colorB hollow tint, colorC grime.
// knobs: x sastrugi strength, y sparkle density, z wind crust (smoother ridges), w grime.
S snow(float2 uv, constant RFParams &P) {
    S s = defaults(); uint sd = P.seed;
    float und = fbm(uv, int2(2, 2), 4, sd + 1u);
    // Elongated along U (wind direction).
    float st = fbm(uv + float2(0.0, 0.05 * und), int2(3, 11), 4, sd + 2u);
    float rd = ridged(uv, int2(2, 8), 4, sd + 3u);
    float saw = fract(uv.x * 5.0 + st * 2.5 + und);
    float step_ = smoothstep(0.0, 0.85, saw) * (1.0 - smoothstep(0.88, 1.0, saw));   // gentle rise, sharp lee drop
    float mask = smoothstep(-0.1, 0.25, fbm(uv, int2(3, 3), 3, sd + 4u));
    float sast = P.f.x * (rd * 0.55 + step_ * 0.35 * mask + st * 0.3);
    float fine = fbm(uv, int2(128, 128), 2, sd + 5u);
    s.height = 0.5 + und * 0.35 + sast * 0.9 + fine * 0.012;
    float hollow = 1.0 - smoothstep(0.3, 0.9, s.height);
    s.albedo = mix(P.colorA.rgb, P.colorB.rgb, hollow * 0.6) * (0.97 + 0.05 * fine);
    float grime = P.f.w * smoothstep(0.0, 0.4, fbm(uv, int2(5, 5), 4, sd + 6u)) * hollow;
    s.albedo = mix(s.albedo, P.colorC.rgb, grime * 0.5);
    s.rough = mix(0.72, 0.42, P.f.z * smoothstep(0.7, 1.1, s.height)) + 0.04 * fine;
    s.ao = mix(0.86, 1.0, 1.0 - hollow);
    int2 gc = wrapc(int2(floor(uv * 1024.0)), int2(1024, 1024));
    if (h01(gc, sd + 7u) > 1.0 - 0.02 * P.f.y) { s.rough = 0.06; s.albedo = min(s.albedo * 1.12, float3(0.86)); }
    s.height *= 0.9;
    return s;
}

// Cobbles and setts in running rows. colorA/B stone tones, colorC joint soil.
// knobs: x wear (polished, flattened tops), y moss in joints, z roundness (0 cut setts, 1 river cobbles),
// w joint fill (0 deep joints, 1 flush with soil).
S cobblestone(float2 uv, constant RFParams &P) {
    S s = defaults(); uint sd = P.seed;
    const float R = 10.0, C = 8.0;
    float2 wp = uv + 0.007 * float2(fbm(uv, int2(12, 12), 2, sd + 1u), fbm(uv, int2(12, 12), 2, sd + 2u));
    float v = wp.y * R;
    float row = floor(v); float fy = v - row;
    int ri = int(row) % int(R); ri = ri < 0 ? ri + int(R) : ri;
    float off = h01(int2(ri, 0), sd + 3u) * C;
    float u = wp.x * C + off;
    float col = floor(u);
    // Jittered column borders (periodic in C).
    #define JB(k) ((k) + (h01(int2(wrapc(int2(int(k), ri), int2(int(C), int(R)))), sd + 4u) - 0.5) * 0.45)
    float b0 = JB(col), b1 = JB(col + 1.0);
    if (u < b0) { b1 = b0; col -= 1.0; b0 = JB(col); }
    else if (u > b1) { b0 = b1; col += 1.0; b1 = JB(col + 1.0); }
    #undef JB
    int ci = int(col) % int(C); ci = ci < 0 ? ci + int(C) : ci;
    int2 sid = int2(ci, ri);
    float id = h01(sid, sd + 5u), id2 = h01(sid, sd + 6u);
    float2 half_ = float2((b1 - b0) / C, 1.0 / R) * 0.5;
    float2 p = float2((u - 0.5 * (b0 + b1)) / C, (fy - 0.5) / R);
    float gap = 0.0012 + 0.0018 * h01(sid, sd + 20u);
    // Each stone shrinks, shifts and turns a little inside its slot.
    float2 shrink = 1.0 - 0.07 * float2(h01(sid, sd + 23u), h01(sid, sd + 24u));
    float2 shift = (float2(h01(sid, sd + 25u), h01(sid, sd + 26u)) - 0.5) * half_ * (1.0 - shrink);
    p = rot2(p - shift, (h01(sid, sd + 27u) - 0.5) * 0.12);
    half_ *= shrink;
    float rc = mix(0.25, 0.85, P.f.z) * (0.7 + 0.3 * h01(sid, sd + 28u)) * min(half_.x, half_.y);
    float2 qd = abs(p) - (half_ - gap - rc);
    float d = length(max(qd, 0.0)) + min(max(qd.x, qd.y), 0.0) - rc;   // < 0 inside
    d += 0.0045 * fbm(uv, int2(36, 36), 3, sd + 22u);                   // irregular outlines
    float e = -d;
    float bevel = mix(0.008, 0.03, P.f.z);
    float sett = sqrt(saturate(e / bevel));
    float2 pn = p / max(half_ - gap, 1e-4);
    float cob = sqrt(saturate(1.0 - dot(pn, pn) * 0.5)) * sqrt(saturate(e / bevel));
    float hs = mix(sett, cob, P.f.z);
    float2 tilt = float2(h01(sid, sd + 7u) - 0.5, h01(sid, sd + 8u) - 0.5);
    float pit = fbm(uv, int2(48, 48), 3, sd + 9u);
    float wear = P.f.x;
    float stoneTop = 0.55 + 0.25 * id + dot(p / half_, tilt) * 0.12;
    float hStone = hs * stoneTop + pit * 0.025 * (1.0 - wear * 0.6);
    hStone = min(hStone, stoneTop - wear * 0.1 + 0.02);
    float jointH = mix(0.05, 0.4, P.f.w) + 0.04 * fbm(uv, int2(32, 32), 2, sd + 10u);
    float fineN = fbm(uv, int2(160, 160), 2, sd + 11u);
    if (e > 0.0 && hStone > jointH) {
        float3 c = mix(P.colorA.rgb, P.colorB.rgb, id) * (0.82 + 0.3 * id2);
        if (id2 > 0.93) c = mix(c, float3(0.3, 0.25, 0.2), 0.25);           // iron-stained stone
        float4 sp = worley(uv, int2(220, 220), sd + 12u, 0.9);
        float grain = smoothstep(0.55, 0.2, sp.x);
        c = mix(c, sp.z < 0.3 ? c * 0.45 : c * 1.25, grain * 0.4);
        float rim = 1.0 - smoothstep(0.0, bevel * 1.5, e);
        c = mix(c, P.colorC.rgb, rim * 0.45);
        float topM = smoothstep(stoneTop - 0.2, stoneTop, hStone);
        s.albedo = c * (0.9 + 0.2 * pit) * mix(0.7, 1.0, smoothstep(0.0, bevel * 2.0, e));
        s.height = hStone + fineN * 0.004;
        s.rough = 0.72 - wear * 0.32 * topM + rim * 0.15;
        s.ao = mix(0.55, 1.0, smoothstep(0.0, bevel * 2.0, e));
    } else {
        float moss = P.f.y * smoothstep(-0.1, 0.25, fbm(uv, int2(6, 6), 4, sd + 13u));
        float3 c = P.colorC.rgb * (0.75 + 0.5 * fineN);
        c = mix(c, float3(0.06, 0.09, 0.025) * (0.8 + 0.5 * fineN), moss);
        float grit = smoothstep(0.5, 0.2, worley(uv, int2(400, 400), sd + 14u, 1.0).x);
        c = mix(c, c * 1.6, grit * 0.25 * (1.0 - moss));
        s.albedo = c;
        s.height = jointH + grit * 0.01 + moss * 0.03;
        s.rough = 0.95;
        s.ao = 0.45 + 0.2 * P.f.w;
    }
    s.height *= 0.9;
    return s;
}

// Packed earth path. colorA earth, colorB dusty crown, colorC roots.
// knobs: x embedded stones, y roots, z dry cracks, w dampness.
S dirtPath(float2 uv, constant RFParams &P) {
    S s = defaults(); uint sd = P.seed;
    float big = fbm(uv, int2(4, 4), 4, sd + 1u);
    float mid = fbm(uv, int2(24, 24), 3, sd + 2u);
    float grit = fbm(uv, int2(192, 192), 2, sd + 3u);
    float h = 0.3 + big * 0.12 + mid * 0.035 + grit * 0.012;
    float dust = smoothstep(-0.1, 0.3, big + mid * 0.5);
    float3 col = mix(P.colorA.rgb, P.colorB.rgb, dust * 0.7) * (0.85 + 0.3 * mid + 0.12 * grit);
    int2 gc = wrapc(int2(floor(uv * 768.0)), int2(768, 768));
    float gh = h01(gc, sd + 4u);
    if (gh < 0.06) col *= 0.6; else if (gh > 0.96) col *= 1.35;
    float4 cr = worley(uv + 0.015 * float2(mid, big), int2(9, 9), sd + 5u, 1.0);
    float crack = (1.0 - smoothstep(0.0, 0.006, cr.y - cr.x)) * P.f.z * smoothstep(0.15, 0.4, big + mid);
    col *= 1.0 - crack * 0.3;
    h -= crack * 0.03;
    s.albedo = col; s.height = h; s.rough = 0.9 - 0.05 * grit; s.ao = mix(0.75, 1.0, smoothstep(0.15, 0.45, h)) * (1.0 - crack * 0.4);
    // Embedded stones, mostly buried.
    for (int layer = 0; layer < 2; layer++) {
        int fr = layer == 0 ? 14 : 34;
        GStone g = gr_stones(uv + float2(0.31, 0.67) * float(layer), int2(fr, fr), sd + 20u + uint(layer) * 11u, 0.8, 0.55);
        if (g.h <= 0.0 || g.id > P.f.x * (layer == 0 ? 0.12 : 0.3)) continue;
        float hh = h - 0.6 / float(fr) + g.h * 1.4;
        if (hh <= s.height) continue;
        float3 c = gr_stoneColor(g.id2, fract(g.id * 13.7), float3(0.2, 0.18, 0.15), float3(0.3, 0.27, 0.22), P.colorB.rgb);
        c = mix(c, P.colorA.rgb, 0.4) * mix(0.6, 1.0, sqrt(saturate(1.0 - g.rr)));
        float bury = smoothstep(0.0, 0.01, hh - s.height);
        s.albedo = mix(s.albedo, c, bury);
        s.height = hh; s.rough = 0.75; s.ao = mix(0.6, 1.0, sqrt(saturate(1.0 - g.rr)));
    }
    // Surface roots: worley borders, masked to a few runs.
    if (P.f.y > 0.0) {
        float2 rw = uv + 0.04 * float2(fbm(uv, int2(5, 5), 3, sd + 6u), fbm(uv, int2(5, 5), 3, sd + 7u));
        float4 rt = worley(rw, int2(4, 4), sd + 8u, 1.0);
        float dist = rt.y - rt.x;
        float width = 0.02 + 0.015 * fbm(uv, int2(8, 8), 2, sd + 9u);
        float on = smoothstep(0.3, 0.1, fbm(uv, int2(3, 3), 3, sd + 10u) + (1.0 - P.f.y) * 0.4);
        float r = dist / width;
        if (r < 1.0 && on > 0.0) {
            float prof = sqrt(1.0 - r * r) * on;
            float bark = fbm(rw, int2(64, 8), 2, sd + 11u);
            s.albedo = mix(s.albedo, P.colorC.rgb * (0.8 + 0.4 * bark), smoothstep(0.0, 0.25, prof));
            s.height = max(s.height, h + prof * 0.03);
            s.rough = mix(s.rough, 0.7, prof); s.ao = mix(s.ao, 1.0, prof);
        }
    }
    float damp = P.f.w * (1.0 - smoothstep(0.2, 0.4, h));
    s.albedo *= 1.0 - damp * 0.35; s.rough = mix(s.rough, 0.55, damp);
    s.height *= 0.8;
    return s;
}
"""#
