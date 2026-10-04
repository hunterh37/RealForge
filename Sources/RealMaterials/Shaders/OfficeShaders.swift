// RealityHD 4 office and interior programs: carpetTile, carpetPile, acousticTile, paintedWall, woodVeneer,
// screenUI, pageEdge, marble, terrazzo, pavers, sansevieria, laminate, chairMesh, pottingSoil.

let metalOffice = #"""
// ---------------------------------------------------------------- office / interiors
inline float3 of_hex(uint h) { return pow(float3(float((h >> 16) & 255u), float((h >> 8) & 255u), float(h & 255u)) / 255.0, 2.2); }
inline float of_box(float2 p, float2 c, float2 h, float r) {
    float2 d = abs(p - c) - h + r; return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0) - r;
}
inline float of_fill(float d, float aa) { return 1.0 - smoothstep(-aa, aa, d); }

// Loop-pile commercial carpet tile. The texture holds 2 x 2 tiles laid quarter-turn (alternate tiles
// rotated 90 degrees), so tileSize = 1.0 gives 50 cm tiles. Tufting rows run along tile-local x.
// colorA yarn, colorB second yarn (a = share of loops), colorC fleck (a = fleck share).
// f.x tufting rows per tile, f.y pattern (multi-level loops and dye streaks), f.z roughness, f.w wear.
S carpetTile(float2 uv, constant RFParams &P) {
    S s = defaults(); uint sd = P.seed;
    float2 g = uv * 2.0; float2 tc = floor(g); float2 t = g - tc;
    int2 ti = wrapc(int2(tc), int2(2, 2));
    bool turn = ((ti.x + ti.y) & 1) == 1;
    float2 q = turn ? float2(t.y, 1.0 - t.x) : t;
    uint ts = sd + uint(ti.x * 2 + ti.y) * 1013u;
    int R = max(8, int(P.f.x)); int L = int(float(R) * 1.25);
    float ry = q.y * float(R); float ri = floor(ry); float fy = ry - ri;
    float stag = fmod(ri, 2.0) * 0.5;
    float rx = q.x * float(L) + stag; float li = floor(rx); float fx = rx - li;
    int2 lid = wrapc(int2(int(li), int(ri)), int2(L, R));
    // Multi-level pattern: low loops form broken streaks along the rows (textured loop tile).
    float pat = fbm(q, int2(2, 10), 4, ts + 5u) + 0.4 * fbm(q, int2(6, 30), 2, ts + 6u);
    float low = smoothstep(0.02, 0.12, pat) * P.f.y;
    float lvl = 1.0 - low * 0.45 + (h01(lid, ts + 3u) - 0.5) * 0.18;
    float across = sin(3.14159265 * fy);
    float along = 0.3 + 0.7 * pow(sat(sin(3.14159265 * fx)), 0.7);
    float prof = pow(sat(across), 0.6) * along;
    // Yarn: heathered loops, plies twist along the loop, rare flecks.
    float r1 = h01(lid, ts + 7u), r2 = h01(lid, ts + 9u);
    float3 yarn = r1 < P.colorB.a ? P.colorB.rgb : P.colorA.rgb;
    float3 other = r1 < P.colorB.a ? P.colorA.rgb : P.colorB.rgb;
    float ply = step(0.5, fract(fx * 2.0 + fy * 1.3 + r2));
    yarn = mix(yarn, other, ply * 0.3);
    if (r2 < P.colorC.a) yarn = mix(yarn, P.colorC.rgb, ply);
    float streak = fbm(q, int2(1, 24), 3, ts + 11u);
    float3 c = yarn * (0.94 + streak * 0.2 * (0.4 + P.f.y)) * (1.0 - low * 0.18);
    c *= mix(0.45, 1.05, prof);
    // Wear: crushed, slightly lighter loops in a broad patch.
    float wear = smoothstep(0.05, 0.4, fbm(uv, int2(2, 2), 4, sd + 21u)) * P.f.w;
    c = mix(c, c * 1.12 + 0.01, wear * 0.5);
    float mott = fbm(uv, int2(4, 4), 4, sd + 23u);
    c *= 0.96 + 0.08 * mott;
    // Seams between tiles: cut loops and a dark hairline.
    float ed = min(min(t.x, 1.0 - t.x), min(t.y, 1.0 - t.y));
    float seam = 1.0 - smoothstep(0.0012, 0.0035, ed);
    c = mix(c, c * 0.35, seam);
    s.albedo = c;
    s.height = sat(0.15 + 0.7 * prof * lvl * (1.0 - wear * 0.3)) * (1.0 - seam * 0.8);
    s.rough = sat(P.f.z - wear * 0.08 + (1.0 - prof) * 0.03);
    s.ao = mix(0.5, 1.0, prof) * (1.0 - seam * 0.5) * (1.0 - low * 0.1);
    s.metal = 0.0; s.alpha = 1.0;
    return s;
}

// Cut-pile (plush) carpet or rug: tuft tips, pile shading, optional border band at the tile edges (map one
// tile over the whole rug to use the border). colorA pile, colorB second yarn (a = heather share), colorC border.
// f.x tufts per tile, f.y pile shading, f.z roughness, f.w border width (fraction of the tile, 0 = none).
S carpetPile(float2 uv, constant RFParams &P) {
    S s = defaults(); uint sd = P.seed;
    int T = max(16, int(P.f.x));
    float2 wuv = uv + float2(fbm(uv, int2(8, 8), 2, sd + 1u), fbm(uv, int2(8, 8), 2, sd + 2u)) * (1.5 / float(T));
    float4 w = worley(wuv, int2(T, T), sd + 3u, 0.95);
    float4 w2 = worley(wuv, int2(T * 2, T * 2), sd + 4u, 0.95);
    float tip = 1.0 - smoothstep(0.0, 0.62, w.x);
    float tip2 = 1.0 - smoothstep(0.0, 0.6, w2.x);
    float fib = gnoise(uv * float2(T * 4, T * 4), int2(T * 4, T * 4), sd + 5u);
    float shade = fbm(uv, int2(3, 3), 5, sd + 6u) * P.f.y;
    float3 yarn = w.z < P.colorB.a ? P.colorB.rgb : P.colorA.rgb;
    float bd = 0.0, groove = 0.0;
    if (P.f.w > 0.0) {
        float ed = min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y));
        bd = 1.0 - smoothstep(P.f.w - 0.002, P.f.w + 0.002, ed);
        groove = 1.0 - smoothstep(0.0, 0.004, abs(ed - P.f.w));
        yarn = mix(yarn, P.colorC.rgb * (0.95 + 0.1 * w.z), bd);
    }
    float3 c = yarn * (0.9 + 0.1 * w2.z) * mix(0.6, 1.0, tip * 0.6 + tip2 * 0.4) * (1.0 + fib * 0.06);
    c *= 1.0 + shade * 0.6;
    c = mix(c, c * 0.55, groove);
    s.albedo = c;
    s.height = sat(0.35 + tip * 0.35 + tip2 * 0.2 + fib * 0.04 - groove * 0.3);
    s.rough = sat(P.f.z - shade * 0.05);
    s.ao = mix(0.6, 1.0, tip * 0.6 + tip2 * 0.4) * (1.0 - groove * 0.4);
    s.metal = 0.0; s.alpha = 1.0;
    return s;
}

// Mineral-fiber acoustic ceiling tile ("fissured"): worm-like fissures, pinholes, granular surface.
// The suspension grid is geometry; the texture is uniform. colorA face, colorB fissure/pit shadow.
// f.x fissures, f.y pinholes, f.z roughness, f.w aging (yellowing, dust).
S acousticTile(float2 uv, constant RFParams &P) {
    S s = defaults(); uint sd = P.seed;
    float fis = 0.0;
    for (int i = 0; i < 3; i++) {
        int F = 24 + i * 14;
        float2 wq = uv + float2(fbm(uv, int2(6, 6), 2, sd + 40u + uint(i)), fbm(uv, int2(6, 6), 2, sd + 50u + uint(i))) * 0.03;
        float n = gnoise(wq * float(F), int2(F, F), sd + 1u + uint(i) * 7u);
        float line = 1.0 - smoothstep(0.0, 0.06, abs(n));
        float seg = smoothstep(-0.05, 0.15, fbm(uv, int2(F * 2, F * 2), 2, sd + 10u + uint(i)));
        fis = max(fis, line * seg);
    }
    fis *= P.f.x;
    float4 ph = worley(uv, int2(150, 150), sd + 20u, 1.0);
    float pin = (1.0 - smoothstep(0.1, 0.2, ph.x)) * step(1.0 - P.f.y, ph.z);
    float4 pit = worley(uv, int2(90, 90), sd + 21u, 1.0);
    float pits = (1.0 - smoothstep(0.08, 0.22, pit.x)) * step(0.6, pit.z) * P.f.x;
    float gran = fbm(uv, int2(200, 200), 2, sd + 22u);
    float mott = fbm(uv, int2(3, 3), 4, sd + 23u);
    float3 c = P.colorA.rgb * (0.97 + gran * 0.08 + mott * 0.04);
    float dark = sat(fis * 0.9 + pin + pits * 0.7);
    c = mix(c, P.colorB.rgb, dark * 0.75);
    float age = smoothstep(-0.1, 0.4, mott) * P.f.w;
    c = mix(c, c * float3(0.95, 0.92, 0.84), age);
    s.albedo = c;
    s.height = 0.6 + gran * 0.08 - fis * 0.35 - pin * 0.3 - pits * 0.2;
    s.rough = sat(P.f.z + dark * 0.04);
    s.ao = 1.0 - dark * 0.45;
    s.metal = 0.0; s.alpha = 1.0;
    return s;
}

// Eggshell latex paint over drywall: roller stipple (orange peel) and faint vertical roller laps.
// colorA paint (tint), colorB unused. f.x stipple, f.y lap variation, f.z roughness, f.w unused.
S paintedWall(float2 uv, constant RFParams &P) {
    S s = defaults(); uint sd = P.seed;
    float peel = fbm(uv, int2(120, 120), 3, sd + 1u);
    float4 w = worley(uv, int2(260, 260), sd + 2u, 1.0);
    float stip = sat(1.0 - w.x * 1.2);
    float lap = fbm(uv, int2(10, 2), 3, sd + 3u);
    float broad = fbm(uv, int2(2, 2), 3, sd + 4u);
    s.albedo = P.colorA.rgb * (1.0 + lap * 0.025 * P.f.y + broad * 0.015 + peel * 0.01);
    s.height = 0.5 + (peel * 0.5 + stip * 0.25) * P.f.x;
    s.rough = sat(P.f.z + lap * 0.06 * P.f.y - stip * 0.03 * P.f.x);
    s.ao = 1.0 - (1.0 - stip) * 0.02 * P.f.x;
    s.metal = 0.0; s.alpha = 1.0;
    return s;
}

// Flat-cut (plain-sliced) veneer: cathedral grain from the slicing plane crossing the growth rings,
// book-matched leaves across V, grain along U. colorA earlywood, colorB latewood, colorC pores and
// rays (a = ray flecks, oak). f.x ring density, f.y cathedral arches per tile along U, f.z pores, f.w leaves per tile (rounded
// to even; 0 or 1 = one flitch).
S woodVeneer(float2 uv, constant RFParams &P) {
    S s = defaults(); uint sd = P.seed;
    int NL = max(1, int(P.f.w + 0.5)); if (NL > 1) NL = (NL + 1) / 2 * 2;
    float lv = uv.y * float(NL); float li = floor(lv); float lf = lv - li;
    float m = fmod(li, 2.0) > 0.5 ? 1.0 - lf : lf;     // mirrored leaf coordinate (book-match)
    float2 lp = float2(uv.x, m);
    // Ring field: x^2 rises toward the leaf edges (straight grain); the ring count falls linearly along U
    // by exactly J rings per tile (periodic modulo whole rings), so contours nest into cathedral arches.
    int J = max(1, int(P.f.y + 0.5));
    float ctr = 0.5 + 0.1 * gnoise(float2(uv.x * 2.0, 0.5), int2(2, 4), sd + 1u);
    float x2 = m - ctr;
    float wob = fbm(lp, int2(6, 3), 4, sd + 2u) * 0.05 + fbm(lp, int2(24, 8), 2, sd + 3u) * 0.008;
    float bend = fbm(float2(uv.x, m * 0.3), int2(3, 1), 3, sd + 10u) * 0.6 / max(P.f.x, 1.0) * float(J);
    float p = (x2 * x2 * 1.6 + wob) * P.f.x + float(J) * (bend - uv.x) + 64.0 * float(J);
    float ri = floor(p); float r = p - ri;
    float rw = h01(int2((int(ri) % J + J) % J, 0), sd + 4u);
    float lw0 = mix(0.55, 0.8, rw);
    float late = smoothstep(lw0, lw0 + 0.18, r) * (1.0 - smoothstep(0.96, 1.0, r));
    float early = 1.0 - smoothstep(0.0, 0.3, r);
    // Fibre streaks along U.
    float fib = gnoise(float2(uv.x * 24.0, m * 160.0), int2(24, 160), sd + 5u) * 0.6
              + gnoise(float2(uv.x * 60.0, m * 420.0), int2(60, 420), sd + 6u) * 0.4;
    // Pores: dashes along U, dense in the earlywood (ring porous) and scattered elsewhere.
    float pn = gnoise(float2(uv.x * 160.0, m * 700.0), int2(160, 700), sd + 7u);
    float pores = smoothstep(0.28, 0.45, pn) * (0.3 + 0.7 * early) * P.f.z;
    // Rays: short spindle flecks along U.
    float cid, cid2; float2 o = cellLocal(lp, int2(90, 40), sd + 8u, cid, cid2);
    float ray = (1.0 - smoothstep(0.7, 1.0, length(o / float2(0.45, 0.07)))) * step(1.0 - P.colorC.a, cid);
    float mott = fbm(uv, int2(3, 3), 4, sd + 9u);
    float3 c = mix(P.colorA.rgb, P.colorB.rgb, sat(late * 0.85 + fib * 0.1));
    c *= 0.93 + 0.12 * (mott + 0.5) * 0.8 + fib * 0.04;
    c = mix(c, P.colorC.rgb, sat(pores * 0.6 + ray * 0.35));
    float seam = 0.0;
    if (NL > 1) seam = 1.0 - smoothstep(0.0, 0.004 * float(NL), min(lf, 1.0 - lf));
    c = mix(c, c * 0.7, seam * 0.6);
    s.albedo = c;
    s.height = 0.5 + late * 0.01 - pores * 0.06 - seam * 0.05 + fib * 0.005;
    s.rough = sat(0.42 + pores * 0.12 - late * 0.03);
    s.ao = 1.0 - pores * 0.15 - seam * 0.2;
    s.metal = 0.0; s.alpha = 1.0;
    return s;
}

// ---- screenUI helpers. Screen space: q.x in [0, 1.6] left to right, q.y in [0, 1] top to bottom.
// One line of greeked text in character cells. Returns coverage; word gets the word index.
float of_line(float x, float fy, float cw, uint rs, float len, thread int &word) {
    word = 0;
    if (x < 0.0 || x > len || fy < 0.0 || fy > 1.0) return 0.0;
    float ci = floor(x / cw); float fx = x / cw - ci;
    float x0 = 0.0;
    for (int i = 0; i < 40; i++) {
        float wl = 2.0 + floor(h01u(rs + uint(i) * 31u) * 8.0);
        if (ci < x0 + wl) { word = i; break; }
        if (ci < x0 + wl + 1.0) return 0.0;
        x0 += wl + 1.0;
    }
    uint cs = rs + uint(ci) * 131u;
    float asc = h01u(cs + 1u) < 0.3 ? 0.12 : 0.34;
    float desc = h01u(cs + 2u) < 0.12 ? 0.92 : 0.78;
    float gx = smoothstep(0.06, 0.2, fx) * (1.0 - smoothstep(0.7, 0.86, fx));
    float gy = smoothstep(asc - 0.06, asc + 0.06, fy) * (1.0 - smoothstep(desc - 0.06, desc + 0.06, fy));
    return gx * gy * (0.8 + 0.2 * h01u(cs + 5u));
}
// Paragraph block: lines of random length. p local (y down), returns coverage.
float of_text(float2 p, float2 size, float lh, float cw, uint seed) {
    if (p.x < 0.0 || p.y < 0.0 || p.x > size.x || p.y > size.y) return 0.0;
    float row = floor(p.y / lh); uint rs = seed + uint(row) * 7919u;
    float len = size.x * (0.35 + 0.65 * h01u(rs + 77u));
    int w; return of_line(p.x, (p.y / lh - row) * 1.25 - 0.1, cw, rs, len, w);
}

constant uint of_dock[12] = { 0x2E8BF0u, 0x34C759u, 0xFF9500u, 0xFF3B30u, 0x5856D6u, 0xF2F2F7u,
                              0x1C1C1Eu, 0x0A84FFu, 0x30B0C7u, 0xFFCC00u, 0xAF52DEu, 0x8E8E93u };
constant uint of_code[6] = { 0xD4D4D4u, 0xC586C0u, 0xDCDCAAu, 0xCE9178u, 0x4EC9B0u, 0x9CDCFEu };

float3 of_sheet(float3 c, float2 l, float2 sz, float aa, uint sd) {
    float3 ink = of_hex(0x202124u), grid = of_hex(0xDADCE0u);
    if (l.y < 0.03) {                                         // toolbar with icon buttons
        c = of_hex(0xF1F3F4u);
        float ix = fmod(l.x - 0.01, 0.026);
        if (l.x > 0.01 && l.x < 0.5 && ix < 0.016 && l.y > 0.008 && l.y < 0.022) c = of_hex(h01u(sd + uint(l.x / 0.026)) < 0.2 ? 0x1A73E8u : 0x5F6368u) * 0.9 + 0.05;
        return c;
    }
    if (l.y < 0.05) {                                         // formula bar
        c = float3(1.0);
        int w; float cov = of_line(l.x - 0.05, (l.y - 0.034) / 0.012, 0.0062, sd + 3u, 0.22, w);
        return mix(c, ink, cov);
    }
    float gy = l.y - 0.05, gx = l.x - 0.032;
    float rh = 0.0185, cwid = 0.072;
    float row = floor(gy / rh), col = floor(gx / cwid);
    float fy = gy / rh - row, fx = gx / cwid - col;
    bool hdrRow = row < 1.0, hdrCol = gx < 0.0;
    c = (hdrRow || hdrCol) ? of_hex(0xF8F9FAu) : float3(1.0);
    uint cs = sd + uint(max(row, 0.0)) * 97u + uint(max(col + 1.0, 0.0)) * 13u;
    // Conditional-format column and a header band.
    if (!hdrRow && !hdrCol && col == 3.0) c = mix(of_hex(0xFCE8E6u), of_hex(0xE6F4EAu), h01u(cs + 9u));
    if (row == 1.0 && !hdrCol) c = of_hex(0xE8F0FEu);
    float cov = 0.0; int w;
    if (hdrRow && !hdrCol) cov = of_line(fx * cwid - cwid * 0.45, fy * 1.3 - 0.15, 0.0062, 5u, 0.006, w);
    else if (hdrCol && !hdrRow) cov = of_line(l.x - 0.012, fy * 1.3 - 0.15, 0.0062, uint(row) * 3u + 1u, 0.006 + step(9.0, row) * 0.004, w);
    else if (h01u(cs) < 0.82 && col < 9.0) {
        float len = cwid * (0.25 + 0.5 * h01u(cs + 1u));
        bool num = col > 0.0 && row > 1.0;
        float x0 = num ? cwid - 0.006 - len : 0.005;
        cov = of_line(fx * cwid - x0, fy * 1.3 - 0.15, 0.0062, cs, len, w);
    }
    c = mix(c, row == 1.0 ? of_hex(0x174EA6u) : ink, cov * (row == 1.0 ? 1.0 : 0.85));
    float lx = min(fx, 1.0 - fx) * cwid, ly = min(fy, 1.0 - fy) * rh;
    float line = max(1.0 - smoothstep(0.0, aa * 1.2, ly), hdrCol ? 0.0 : 1.0 - smoothstep(0.0, aa * 1.2, lx));
    c = mix(c, grid, line);
    // Selection range.
    float sel = of_box(l, float2(0.032 + cwid * 5.0, 0.05 + rh * 6.0), float2(cwid, rh * 2.0), 0.0);
    if (sel < 0.0) c = mix(c, of_hex(0x1A73E8u), 0.08);
    c = mix(c, of_hex(0x1A73E8u), 1.0 - smoothstep(0.0, aa * 1.5, abs(sel)));
    // Embedded bar chart.
    float2 cc = float2(sz.x - 0.2, 0.3), ch = float2(0.17, 0.11);
    float cb = of_box(l, cc, ch, 0.004);
    if (cb < 0.0) {
        c = float3(1.0);
        float2 cl = l - (cc - ch);
        float base = ch.y * 2.0 - 0.02;
        if (abs(cl.y - base) < aa) c = grid;
        float gi = floor((cl.x - 0.02) / 0.05), gf = fmod(cl.x - 0.02, 0.05);
        if (gi >= 0.0 && gi < 6.0 && gf < 0.036) {
            int bi = int(gf / 0.012);
            float hgt = (0.03 + 0.13 * h01u(sd + uint(gi) * 11u + uint(bi))) * (bi == 0 ? 1.0 : 0.8);
            uint bc = bi == 0 ? 0x4285F4u : (bi == 1 ? 0xEA4335u : 0xFBBC04u);
            if (cl.y < base && cl.y > base - hgt && fmod(gf, 0.012) < 0.0105) c = of_hex(bc);
        }
        int w2; float tc = of_line(cl.x - 0.12, (cl.y - 0.008) / 0.014, 0.0066, sd + 61u, 0.1, w2);
        c = mix(c, ink, tc);
    }
    c = mix(c, grid * 0.85, 1.0 - smoothstep(0.0, aa * 1.5, abs(cb)));
    return c;
}

float3 of_editor(float3 c, float2 l, float2 sz, float aa, uint sd) {
    if (l.x < 0.13) {                                         // file tree
        c = of_hex(0x252526u);
        float lh = 0.016, row = floor(l.y / lh);
        if (row == 4.0) c = of_hex(0x37373Du);
        uint rs = sd + uint(row) * 37u;
        float ind = 0.012 + floor(h01u(rs) * 3.0) * 0.008;
        int w; float cov = of_line(l.x - ind, (l.y / lh - row) * 1.3 - 0.15, 0.0062, rs, 0.03 + 0.05 * h01u(rs + 1u), w);
        return mix(c, of_hex(0xCCCCCCu), cov * 0.85);
    }
    float2 e = l - float2(0.13, 0.0);
    if (e.y < 0.022) {                                        // tabs
        c = of_hex(0x2D2D2Du);
        if (e.x < 0.12) c = of_hex(0x1E1E1Eu);
        float tx = fmod(e.x, 0.12);
        int w; float cov = of_line(tx - 0.015, (e.y - 0.006) / 0.012, 0.0062, sd + uint(e.x / 0.12) * 5u, 0.06, w);
        c = mix(c, of_hex(e.x < 0.12 ? 0xFFFFFFu : 0x969696u), cov);
        if (abs(tx - 0.12) < aa || tx < aa) c = of_hex(0x252526u);
        return c;
    }
    c = of_hex(0x1E1E1Eu);
    float lh = 0.0135, gy = e.y - 0.03, row = floor(gy / lh), fy = gy / lh - row;
    if (gy < 0.0) return c;
    if (row == 9.0) c = of_hex(0x2A2D2Eu);
    uint rs = sd + uint(row) * 7919u;
    // Line numbers.
    int w; float num = of_line(e.x - 0.012 + (row >= 9.0 ? 0.0062 : 0.0), fy * 1.25 - 0.1, 0.0062, rs + 5u, row >= 9.0 ? 0.0124 : 0.0062, w);
    c = mix(c, of_hex(row == 9.0 ? 0xC6C6C6u : 0x858585u), num * 0.9);
    // Code: indentation follows a block structure; blank lines and comments.
    float blank = h01u(rs + 1u) < 0.1 ? 1.0 : 0.0;
    float ind = floor(fmod(row * 0.37 + h01u(sd + uint(row / 6.0)) * 3.0, 4.0)) * 0.0248;
    bool comment = h01u(rs + 2u) < 0.12;
    float len = blank > 0.0 ? 0.0 : 0.04 + 0.26 * h01u(rs + 3u);
    float cov = of_line(e.x - 0.045 - ind, fy * 1.25 - 0.1, 0.0062, rs, len, w);
    uint ci = comment ? 0x6A9955u : of_code[(w == 0 ? 1 : (int(h01u(rs + uint(w) * 19u) * 6.0))) % 6];
    c = mix(c, of_hex(ci), cov);
    if (abs(e.x - 0.045 - 0.0248) < aa * 0.6 && ind > 0.01) c = mix(c, of_hex(0x404040u), 0.8);   // indent guide
    return c;
}

float3 of_messages(float3 c, float2 l, float2 sz, float aa, uint sd) {
    if (l.x < 0.15) {                                         // conversation list
        c = of_hex(0xF2F2F7u);
        float rh = 0.05, row = floor(l.y / rh), fy = l.y - row * rh;
        if (row == 1.0) c = of_hex(0x0A84FFu);
        float av = length(float2(l.x - 0.02, fy - rh * 0.5)) - 0.012;
        c = mix(c, of_hex(of_dock[uint(row * 3.0) % 12u]) * 0.9, of_fill(av, aa));
        float3 ink = row == 1.0 ? float3(1.0) : of_hex(0x1C1C1Eu);
        int w; float t1 = of_line(l.x - 0.04, (fy - 0.012) / 0.012, 0.0062, sd + uint(row) * 11u, 0.05, w);
        float t2 = of_line(l.x - 0.04, (fy - 0.028) / 0.011, 0.0056, sd + uint(row) * 17u, 0.09, w);
        c = mix(c, ink, t1);
        c = mix(c, row == 1.0 ? float3(0.85) : of_hex(0x8E8E93u), t2);
        if (abs(fy) < aa && row > 0.0) c = of_hex(0xD1D1D6u);
        return c;
    }
    c = float3(1.0);
    float2 m = l - float2(0.15, 0.0); float w = sz.x - 0.15;
    // Bubbles, alternating sides.
    for (int i = 0; i < 5; i++) {
        uint bs = sd + uint(i) * 53u;
        bool mine = (i % 2) == 1 || h01u(bs) < 0.3;
        float bw = 0.07 + 0.12 * h01u(bs + 1u), bh = 0.022 + (h01u(bs + 2u) < 0.4 ? 0.013 : 0.0);
        float y = 0.02 + float(i) * 0.052;
        float2 bc = float2(mine ? w - 0.015 - bw * 0.5 : 0.015 + bw * 0.5, y + bh * 0.5);
        float d = of_box(m, bc, float2(bw, bh) * 0.5, 0.01);
        if (d < aa) {
            float3 bcol = mine ? of_hex(0x0A84FFu) : of_hex(0xE9E9EBu);
            c = mix(c, bcol, of_fill(d, aa));
            float tc = of_text(m - (bc - float2(bw, bh) * 0.5) - float2(0.008, 0.006), float2(bw - 0.016, bh - 0.008), 0.013, 0.0062, bs + 7u);
            c = mix(c, mine ? float3(1.0) : of_hex(0x1C1C1Eu), tc * of_fill(d, aa));
        }
    }
    float ib = of_box(m, float2(w * 0.5, sz.y - 0.045), float2(w * 0.5 - 0.015, 0.011), 0.011);
    c = mix(c, of_hex(0xC7C7CCu), 1.0 - smoothstep(0.0, aa * 1.5, abs(ib)));
    return c;
}

float3 of_window(float3 c, float2 q, float4 rect, int kind, uint sd, float aa) {
    float2 ctr = (rect.xy + rect.zw) * 0.5, hs = (rect.zw - rect.xy) * 0.5;
    float r = 0.01;
    float dsh = of_box(q, ctr + float2(0.0, 0.012), hs + 0.004, r);
    c *= 1.0 - 0.45 * (1.0 - smoothstep(-0.01, 0.035, dsh));
    float d = of_box(q, ctr, hs, r);
    if (d > aa) return c;
    float2 l = q - rect.xy, sz = rect.zw - rect.xy;
    float tb = 0.026;
    bool dark = kind == 1;
    float3 w;
    if (l.y < tb) {
        w = dark ? of_hex(0x323233u) : of_hex(0xECECECu);
        uint tl[3] = { 0xFF5F57u, 0xFEBC2Eu, 0x28C840u };
        for (int i = 0; i < 3; i++) {
            float dc = length(l - float2(0.016 + 0.018 * float(i), tb * 0.5)) - 0.0055;
            w = mix(w, of_hex(tl[i]), of_fill(dc, aa));
        }
        int wd; float tc = of_line(l.x - sz.x * 0.5 + 0.035, (l.y - 0.008) / 0.012, 0.0066, sd + 1u, 0.07, wd);
        w = mix(w, dark ? of_hex(0xCCCCCCu) : of_hex(0x4D4D4Du), tc);
        if (abs(l.y - tb) < aa) w = dark ? of_hex(0x1A1A1Au) : of_hex(0xD0D0D0u);
    } else {
        float2 cl = l - float2(0.0, tb);
        float2 csz = sz - float2(0.0, tb);
        if (kind == 0) w = of_sheet(float3(1.0), cl, csz, aa, sd + 3u);
        else if (kind == 1) w = of_editor(float3(0.0), cl, csz, aa, sd + 3u);
        else w = of_messages(float3(1.0), cl, csz, aa, sd + 3u);
    }
    w = mix(w, dark ? of_hex(0x505050u) : of_hex(0xB0B0B0u), 1.0 - smoothstep(0.0, aa * 1.5, abs(d)));
    return mix(c, w, of_fill(d, aa));
}

// Emissive desktop for display panels (atlas: UVs 0...1 across a 16:10 screen, v up the panel). Wallpaper,
// menu bar, dock and three app windows (spreadsheet, code editor, messages). Not tileable.
// colorA wallpaper deep, colorB wallpaper light, colorC ribbon glow. f.x ribbon strength, f.y dim (0 full).
S screenUI(float2 uv, constant RFParams &P) {
    S s = defaults(); uint sd = P.seed;
    float2 q = float2(uv.x * 1.6, uv.y);   // unlit display path samples v down
    float aa = 1.0 / float(P.size);
    float t = q.y * 0.9 + 0.22 * sin(q.x * 2.3 + 1.0) + 0.12 * sin(q.x * 5.1 + q.y * 3.0);
    float3 c = mix(P.colorA.rgb, P.colorB.rgb, smoothstep(0.05, 1.0, t));
    float rib = 1.0 - smoothstep(0.0, 0.22, abs(t - 0.55 - 0.08 * sin(q.x * 3.7)));
    c = mix(c, P.colorC.rgb, rib * rib * P.f.x);
    c = of_window(c, q, float4(0.10, 0.07, 1.02, 0.72), 0, sd + 10u, aa);
    c = of_window(c, q, float4(0.04, 0.50, 0.52, 0.88), 2, sd + 20u, aa);
    c = of_window(c, q, float4(0.80, 0.15, 1.53, 0.84), 1, sd + 30u, aa);
    // Menu bar.
    if (q.y < 0.022) {
        c = mix(c, of_hex(0xF2F2F2u), 0.7);
        float3 ink = of_hex(0x1C1C1Eu);
        c = mix(c, ink, of_fill(length(q - float2(0.018, 0.011)) - 0.005, aa));
        int w; float m1 = of_line(q.x - 0.034, (q.y - 0.006) / 0.011, 0.0066, sd + 90u, 0.3, w);
        float m2 = of_line(q.x - 1.43, (q.y - 0.006) / 0.011, 0.0066, sd + 91u, 0.16, w);
        c = mix(c, ink, max(m1, m2));
        for (int i = 0; i < 4; i++) {
            float ib = of_box(q, float2(1.3 + float(i) * 0.03, 0.011), float2(0.007, 0.0066), 0.002);
            c = mix(c, ink, of_fill(ib, aa) * 0.85);
        }
    }
    // Dock.
    float dk = of_box(q, float2(0.8, 0.957), float2(0.32, 0.032), 0.02);
    if (dk < aa) {
        c = mix(c, mix(c, float3(0.9), 0.45), of_fill(dk, aa));
        c = mix(c, float3(0.95), (1.0 - smoothstep(0.0, aa * 1.5, abs(dk))) * 0.6);
        for (int i = 0; i < 12; i++) {
            float2 ic = float2(0.8 + (float(i) - 5.5) * 0.052, 0.955);
            float di = of_box(q, ic, float2(0.021), 0.009);
            if (di < aa) {
                float3 col = of_hex(of_dock[i]) * (1.05 - 0.25 * (q.y - ic.y + 0.021) / 0.042);
                float2 lq = q - ic;
                float glyph = (i % 3 == 0) ? of_fill(length(lq) - 0.009, aa)
                            : (i % 3 == 1 ? of_fill(of_box(lq, float2(0.0), float2(0.01, 0.007), 0.002), aa)
                                          : of_fill(abs(length(lq) - 0.01) - 0.0025, aa));
                col = mix(col, (i == 5 || i == 9) ? of_hex(0x3A3A3Cu) : float3(0.97), glyph * 0.9);
                c = mix(c, col, of_fill(di, aa));
            }
            if (i % 4 != 3) c = mix(c, of_hex(0x3A3A3Cu), of_fill(length(q - float2(ic.x, 0.983)) - 0.0018, aa));
        }
    }
    s.albedo = c * (1.0 - P.f.y);
    s.height = 0.5; s.rough = 0.1; s.ao = 1.0; s.metal = 0.0; s.alpha = 1.0;
    return s;
}

// Page block edge: stacked sheets as fine lines along U, gently wavy, faint thumb dirt.
// One V tile = f.x sheets (tileSize 0.01 = 1 cm of pages). colorA paper, colorB shadow between
// sheets, colorC dirt. f.x sheets per tile, f.y dirt, f.z waviness, f.w signature gaps (0...1).
S pageEdge(float2 uv, constant RFParams &P) {
    S s = defaults(); uint sd = P.seed;
    int N = max(8, int(P.f.x));
    float wav = (gnoise(uv * float2(1, 6), int2(1, 6), sd + 1u) * 1.2 + gnoise(uv * float2(2, 14), int2(2, 14), sd + 2u) * 0.5) * P.f.z;
    float sv = uv.y * float(N) + wav;
    float si = floor(sv); float f = sv - si;
    int sid = ((int(si) % N) + N) % N;
    float tone = h01(int2(sid, 0), sd + 3u);
    float proud = h01(int2(sid, 0), sd + 4u);
    float gapW = 0.12 + 0.18 * step(1.0 - P.f.w * 0.15, h01(int2(sid, 0), sd + 5u));
    float gap = 1.0 - smoothstep(0.0, gapW, min(f, 1.0 - f));
    float prof = sqrt(sat(sin(3.14159265 * f)));
    float fib = gnoise(float2(uv.x * 40.0, sv * 1.0), int2(40, N), sd + 6u);
    float dirt = smoothstep(0.0, 0.5, fbm(uv, int2(2, 1), 4, sd + 7u) + fbm(uv, int2(1, 2), 3, sd + 8u) * 0.5) * P.f.y;
    float3 c = P.colorA.rgb * (0.95 + 0.07 * tone + fib * 0.03);
    c = mix(c, P.colorC.rgb, dirt * (0.5 + 0.5 * proud));
    c = mix(c, P.colorB.rgb, gap * 0.8);
    s.albedo = c;
    s.height = 0.4 + prof * 0.4 + proud * 0.08 - gap * 0.2;
    s.rough = sat(0.88 + gap * 0.05 - dirt * 0.08);
    s.ao = 1.0 - gap * 0.45;
    s.metal = 0.0; s.alpha = 1.0;
    return s;
}

// Polished marble: domain-warped branching veins over cloudy ground. colorA ground, colorB veins,
// colorC clouds (a = cloud amount). f.x vein frequency, f.y warp, f.z vein width, f.w roughness.
S marble(float2 uv, constant RFParams &P) {
    S s = defaults(); uint sd = P.seed;
    float2 w1 = float2(fbm(uv, int2(2, 2), 5, sd + 1u), fbm(uv, int2(2, 2), 5, sd + 2u));
    float2 p = uv + w1 * P.f.y * 0.6;
    float2 w2 = float2(fbm(p, int2(5, 5), 4, sd + 3u), fbm(p, int2(5, 5), 4, sd + 4u));
    float2 p2 = p + w2 * P.f.y * 0.2;
    int F = max(1, int(P.f.x));
    float wv = P.f.z * (0.6 + 0.8 * sat(fbm(uv, int2(4, 4), 3, sd + 5u) + 0.5));
    float n1 = sin(6.2831853 * (p2.x * float(F) + p2.y)) * 0.18 + fbm(p2, int2(F + 1, F + 1), 5, sd + 6u);
    float v1 = 1.0 - smoothstep(wv * 0.3, wv, abs(n1));
    float halo1 = 1.0 - smoothstep(wv, wv * 3.0, abs(n1));
    float n2 = fbm(p2 * 1.0 + w1 * 0.3, int2(F * 3, F * 3), 4, sd + 7u);
    float m2 = smoothstep(0.0, 0.25, fbm(uv, int2(3, 3), 3, sd + 8u) + halo1 * 0.3);
    float v2 = (1.0 - smoothstep(wv * 0.12, wv * 0.45, abs(n2))) * m2;
    float n3 = fbm(p2 + w2 * 0.2, int2(F * 7, F * 7), 3, sd + 9u);
    float m3 = smoothstep(0.05, 0.3, fbm(uv, int2(5, 5), 3, sd + 10u));
    float v3 = (1.0 - smoothstep(wv * 0.04, wv * 0.18, abs(n3))) * m3;
    float cloud = smoothstep(-0.2, 0.45, fbm(p, int2(3, 3), 6, sd + 11u)) * P.colorC.a;
    float grain = fbm(uv, int2(64, 64), 2, sd + 12u);
    float3 c = P.colorA.rgb * (0.97 + grain * 0.06);
    c = mix(c, P.colorC.rgb, cloud);
    c = mix(c, mix(c, P.colorB.rgb, 0.3), halo1 * 0.3);
    c = mix(c, P.colorB.rgb, sat(v1 * 0.95 + v2 * 0.7 + v3 * 0.45));
    s.albedo = c;
    s.height = 0.5 + grain * 0.01 - v1 * 0.01;
    s.rough = sat(P.f.w + v1 * 0.03 + grain * 0.02);
    s.ao = 1.0;
    s.metal = 0.0; s.alpha = 1.0;
    return s;
}

// Ground and polished terrazzo: cement matrix with angular marble chips in three sizes.
// colorA matrix, colorB chip 1, colorC chip 2 (a = chip-2 share); a third chip is near-white.
// f.x large chips per tile, f.y coverage, f.z roughness, f.w white-chip share.
S terrazzo(float2 uv, constant RFParams &P) {
    S s = defaults(); uint sd = P.seed;
    float sand = fbm(uv, int2(180, 180), 2, sd + 1u);
    float4 sp = worley(uv, int2(320, 320), sd + 2u, 1.0);
    float speck = (1.0 - smoothstep(0.12, 0.3, sp.x)) * (sp.z < 0.5 ? -1.0 : 1.0);
    float3 c = P.colorA.rgb * (0.95 + sand * 0.1 + speck * 0.08);
    float chip = 0.0, edge = 0.0;
    int F0 = max(4, int(P.f.x));
    for (int i = 0; i < 3 && chip < 0.5; i++) {
        int F = int(float(F0) * (i == 0 ? 1.0 : (i == 1 ? 2.3 : 5.0)));
        float2 wq = uv + float2(fbm(uv, int2(F, F), 2, sd + 10u + uint(i)), fbm(uv, int2(F, F), 2, sd + 20u + uint(i))) * (0.35 / float(F));
        float4 w = worley(wq, int2(F, F), sd + 30u + uint(i) * 17u, 1.0);
        float present = step(w.z, mix(0.25, 0.95, P.f.y));
        float thr = mix(0.55, 0.12, P.f.y) * (0.7 + 0.6 * h01u(uint(w.w * 65535.0) + sd));
        float e = w.y - w.x;
        float inside = smoothstep(thr, thr + 0.03, e) * present;
        if (inside > 0.0) {
            float pick = h01u(uint(w.z * 65535.0) + 7u);
            float3 cc = pick < P.f.w ? of_hex(0xE8E5DEu) : (pick < P.f.w + (1.0 - P.f.w) * P.colorC.a ? P.colorC.rgb : P.colorB.rgb);
            float vein = gnoise(uv * float(F * 6), int2(F * 6, F * 6), sd + 40u + uint(i));
            cc *= 0.88 + 0.24 * w.w + vein * 0.08;
            c = mix(c, cc, inside);
            edge = max(edge, (1.0 - smoothstep(0.0, 0.05, abs(e - thr))) * present);
            chip = max(chip, inside);
        }
    }
    s.albedo = c * (1.0 - edge * 0.12);
    s.height = 0.5 + chip * 0.004 + sand * 0.004;
    s.rough = sat(P.f.z + (1.0 - chip) * 0.08 + edge * 0.05);
    s.ao = 1.0 - edge * 0.05;
    s.metal = 0.0; s.alpha = 1.0;
    return s;
}

// Large-format concrete pavers with sand joints. colorA concrete, colorB weathering stain, colorC joint sand.
// f.x slabs per tile (tileSize 2.4 with 4 = 60 cm slabs), f.y tone variation, f.z weathering,
// f.w joint width as a fraction of a slab (0.01 = 6 mm on 60 cm).
S pavers(float2 uv, constant RFParams &P) {
    S s = defaults(); uint sd = P.seed;
    int N = max(1, int(P.f.x));
    float2 g = uv * float(N); float2 cell = floor(g); float2 f = g - cell;
    int2 ci = wrapc(int2(cell), int2(N, N));
    float aa = float(N) / float(P.size);
    float d = min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y));
    float jw = max(P.f.w, aa) * 0.5;
    float joint = 1.0 - smoothstep(jw - aa * 0.5, jw + aa * 0.5, d);
    float chamfer = 1.0 - smoothstep(jw, jw + 0.007, d);
    float tone = h01(ci, sd + 1u) - 0.5;
    float2 tilt = float2(h01(ci, sd + 2u), h01(ci, sd + 3u)) - 0.5;
    float4 ag = worley(uv, int2(N * 90, N * 90), sd + 4u, 1.0);
    float agg = (1.0 - smoothstep(0.15, 0.4, ag.x)) * (ag.z - 0.5);
    float fine = fbm(uv, int2(N * 40, N * 40), 3, sd + 5u);
    float4 pt = worley(uv, int2(N * 30, N * 30), sd + 6u, 1.0);
    float pit = (1.0 - smoothstep(0.05, 0.14, pt.x)) * step(0.75, pt.z);
    float stain = smoothstep(0.0, 0.45, fbm(uv, int2(3, 3), 5, sd + 7u)) * P.f.z;
    float edgeDirt = (1.0 - smoothstep(jw, jw + 0.06, d)) * P.f.z;
    float3 c = P.colorA.rgb * (1.0 + tone * P.f.y * 0.35 + agg * 0.18 + fine * 0.08);
    c = mix(c, P.colorB.rgb, sat(stain * 0.45 + edgeDirt * 0.35));
    c *= 1.0 - pit * 0.35;
    c = mix(c, c * 0.72, chamfer * (1.0 - joint));
    float sandN = gnoise(uv * float(N * 160), int2(N * 160, N * 160), sd + 8u);
    float3 sand = P.colorC.rgb * (0.85 + sandN * 0.3);
    c = mix(c, sand, joint);
    s.albedo = c;
    float slab = 0.62 + dot(f - 0.5, tilt) * 0.03 + fine * 0.02 - pit * 0.08;
    s.height = mix(slab - chamfer * 0.12 * (1.0 - smoothstep(jw, jw + 0.007, d)), 0.3 + sandN * 0.03, joint);
    s.rough = sat(0.86 + fine * 0.04 - stain * 0.05 + joint * 0.08);
    s.ao = 1.0 - joint * 0.4 - chamfer * 0.15 - pit * 0.3;
    s.metal = 0.0; s.alpha = 1.0;
    return s;
}

// Sansevieria (snake plant) leaf. UV mapping: u = 0...1 across the leaf width (margins at u = 0 and 1),
// v along the leaf from base to tip; one V repeat = one leaf length (tileSize 1, UVs normalized per leaf;
// offset v per leaf for variety). colorA dark green, colorB grey-green cross bands, colorC margin yellow.
// f.x bands per leaf, f.y zigzag amplitude, f.z roughness, f.w margin width (fraction of width, 0 = none).
S sansevieria(float2 uv, constant RFParams &P) {
    S s = defaults(); uint sd = P.seed;
    int NB = max(4, int(P.f.x));
    float tri = (abs(fract(uv.x * 3.0 + 0.25) - 0.5) * 2.0 - 0.5) * (0.7 + 0.6 * fbm(uv, int2(2, NB), 2, sd + 9u));
    float wob = fbm(uv, int2(3, NB), 3, sd + 1u);
    float y = uv.y * float(NB) + tri * P.f.y + wob * 0.9;
    float bi = floor(y); float fy = y - bi;
    int bid = ((int(bi) % NB) + NB) % NB;
    float bw = mix(0.25, 0.6, h01(int2(bid, 0), sd + 2u));
    float br = fbm(uv, int2(6, NB * 2), 3, sd + 3u);
    float band = smoothstep(0.0, 0.08, fy) * (1.0 - smoothstep(bw, bw + 0.1, fy)) * smoothstep(-0.25, 0.1, br);
    // Fine dashes and mottling between the bands.
    float4 dw = worley(uv, int2(10, NB * 3), sd + 4u, 1.0);
    float dash = (1.0 - smoothstep(0.15, 0.3, dw.x)) * step(0.55, dw.z) * 0.6;
    float stri = gnoise(float2(uv.x * 48.0, uv.y * 4.0), int2(48, 4), sd + 5u);
    float3 c = P.colorA.rgb * (0.9 + 0.2 * (fbm(uv, int2(4, 8), 3, sd + 6u) + 0.5) + stri * 0.06);
    c = mix(c, P.colorB.rgb * (0.9 + 0.2 * br), sat(band * 0.85 + dash * (1.0 - band)));
    float mar = 0.0;
    if (P.f.w > 0.0) {
        float e = min(uv.x, 1.0 - uv.x) + gnoise(float2(uv.x * 2.0, uv.y * 30.0), int2(2, 30), sd + 7u) * P.f.w * 0.1;
        mar = 1.0 - smoothstep(P.f.w * 0.85, P.f.w, e);
        float rim = (1.0 - smoothstep(0.0, P.f.w * 0.2, abs(e - P.f.w))) * 0.6;
        float ms = gnoise(float2(uv.x * 60.0, uv.y * 3.0), int2(60, 3), sd + 8u);
        c = mix(c, P.colorC.rgb * (0.9 + ms * 0.2), mar);
        c = mix(c, P.colorA.rgb * 0.8, rim);
    }
    s.albedo = c;
    s.height = 0.5 + stri * 0.03 + band * 0.01;
    s.rough = sat(P.f.z + band * 0.05 + mar * 0.05);
    s.ao = 1.0;
    s.metal = 0.0; s.alpha = 1.0;
    return s;
}

// Fine dense surfaces: high-pressure laminate (suede emboss) and paper (formation flocs).
// colorA color, colorB unused. f.x emboss, f.y flocs (paper formation), f.z roughness, f.w speckle.
S laminate(float2 uv, constant RFParams &P) {
    S s = defaults(); uint sd = P.seed;
    float4 w = worley(uv, int2(300, 300), sd + 1u, 1.0);
    float emb = sqrt(sat(1.0 - w.x));
    float fine = fbm(uv, int2(150, 150), 3, sd + 2u);
    float floc = fbm(uv, int2(60, 60), 4, sd + 3u);
    float4 sp = worley(uv, int2(120, 120), sd + 4u, 1.0);
    float speck = (1.0 - smoothstep(0.04, 0.1, sp.x)) * step(0.85, sp.z) * P.f.w;
    float broad = fbm(uv, int2(2, 2), 3, sd + 5u);
    float3 c = P.colorA.rgb * (1.0 + floc * 0.05 * P.f.y + broad * 0.015 + fine * 0.01);
    c = mix(c, c * 0.6, speck);
    s.albedo = c;
    s.height = 0.5 + (emb * 0.5 + fine * 0.3) * P.f.x + floc * 0.3 * P.f.y;
    s.rough = sat(P.f.z - emb * 0.06 * P.f.x + broad * 0.03);
    s.ao = 1.0 - (1.0 - emb) * 0.05 * P.f.x;
    s.metal = 0.0; s.alpha = 1.0;
    return s;
}

// Elastomeric office-chair mesh: glossy monofilaments along V bound by fine multifilament weft along U,
// open gaps between (dark, opaque). colorA strand, colorB weft, colorC gap.
// f.x strands per tile, f.y openness (0...1), f.z roughness, f.w weft picks per strand pitch.
S chairMesh(float2 uv, constant RFParams &P) {
    S s = defaults(); uint sd = P.seed;
    int N = max(4, int(P.f.x));
    float2 g = uv * float(N); float2 cell = floor(g); float2 f = g - cell;
    float open = P.f.y;
    float sw = mix(0.75, 0.42, open);
    float dx = abs(f.x - 0.5) / (sw * 0.5);
    float mono = dx < 1.0 ? sqrt(1.0 - dx * dx) : -1.0;
    // Weft: pairs of fine threads every pick, passing over and under the monofilaments.
    float picks = max(1.0, floor(P.f.w + 0.5));
    float wy = fract(g.y * picks);
    float ww = mix(0.7, 0.35, open);
    float dy = abs(wy - 0.5) / (ww * 0.5);
    float weft = dy < 1.0 ? sqrt(1.0 - dy * dy) : -1.0;
    float over = cos(3.14159265 * (g.x - 0.5) + 3.14159265 * floor(g.y * picks)) * 0.15;
    float hm = mono >= 0.0 ? 0.55 + mono * 0.35 : -1.0;
    float hw = weft >= 0.0 ? 0.5 + over + weft * 0.2 : -1.0;
    bool top = hm >= hw;
    float h = max(hm, hw);
    float gap = h < 0.0 ? 1.0 : 0.0;
    float fibr = gnoise(uv * float2(N * 8, N * 8), int2(N * 8, N * 8), sd + 1u);
    float3 c = top ? P.colorA.rgb * mix(0.6, 1.15, mono) : P.colorB.rgb * mix(0.65, 1.0, sat(weft)) * (1.0 + fibr * 0.1);
    if (gap > 0.5) c = P.colorC.rgb;
    s.albedo = c;
    s.height = gap > 0.5 ? 0.0 : sat(h);
    s.rough = gap > 0.5 ? 0.9 : (top ? sat(P.f.z - mono * 0.2) : sat(P.f.z + 0.2));
    s.ao = gap > 0.5 ? 0.25 : mix(0.65, 1.0, sat(top ? mono : weft));
    s.metal = 0.0; s.alpha = 1.0;
    return s;
}

// Potting mix: dark peat crumbs, bark fragments and white perlite granules. colorA peat, colorB bark,
// colorC perlite. f.x perlite amount, f.y bark amount, f.z moisture (darker, glossier), f.w crumb scale.
S pottingSoil(float2 uv, constant RFParams &P) {
    S s = defaults(); uint sd = P.seed;
    int C = max(20, int(P.f.w));
    float4 cr = worley(uv, int2(C, C), sd + 1u, 1.0);
    float4 cr2 = worley(uv, int2(C * 3, C * 3), sd + 2u, 1.0);
    float crumb = sqrt(sat(1.0 - cr.x)) * 0.6 + sqrt(sat(1.0 - cr2.x)) * 0.4;
    float clump = fbm(uv, int2(12, 12), 3, sd + 11u);
    float crev = (1.0 - smoothstep(0.0, 0.3, cr.y - cr.x)) * 0.5 * smoothstep(-0.3, 0.2, clump) + (1.0 - smoothstep(0.0, 0.2, cr2.y - cr2.x)) * 0.3;
    float3 c = P.colorA.rgb * (0.75 + 0.3 * cr.z + 0.2 * cr2.z + clump * 0.6) * mix(0.65, 1.1, crumb);
    float hgt = crumb * 0.5;
    // Bark fragments: elongated, rotated flakes.
    float bark = 0.0;
    {
        float cid, cid2; float2 o = cellLocal(uv, int2(C / 5, C / 5), sd + 3u, cid, cid2);
        float2 r = rot2(o, cid2 * 6.2831853);
        float dd = length(r / float2(0.42, 0.16)) + gnoise(uv * float(C), int2(C, C), sd + 4u) * 0.25;
        bark = (1.0 - smoothstep(0.85, 1.0, dd)) * step(1.0 - P.f.y, cid);
        float fibre = gnoise(float2(r.x * 30.0, r.y * 4.0) + cid * 50.0, int2(64, 64), sd + 5u);
        c = mix(c, P.colorB.rgb * (0.8 + 0.4 * cid2 + fibre * 0.15), bark);
        hgt = mix(hgt, 0.75 + fibre * 0.05, bark);
    }
    // Perlite: bright, lumpy, porous granules.
    float per = 0.0;
    {
        float cid, cid2; float2 o = cellLocal(uv, int2(C / 4, C / 4), sd + 6u, cid, cid2);
        float dd = length(o) / (0.18 + 0.12 * cid2) + gnoise(uv * float(C * 2), int2(C * 2, C * 2), sd + 7u) * 0.35;
        per = (1.0 - smoothstep(0.85, 1.0, dd)) * step(1.0 - P.f.x, cid);
        float pore = worley(uv, int2(C * 8, C * 8), sd + 8u, 1.0).x;
        c = mix(c, P.colorC.rgb * (0.85 + 0.15 * smoothstep(0.1, 0.5, pore)), per);
        hgt = mix(hgt, 0.85 + (1.0 - dd) * 0.1, per);
    }
    float wet = P.f.z * smoothstep(-0.2, 0.3, fbm(uv, int2(3, 3), 3, sd + 9u));
    c *= 1.0 - wet * 0.35 * (1.0 - per);
    c *= 1.0 - crev * 0.5 * (1.0 - per) * (1.0 - bark);
    s.albedo = c;
    s.height = hgt - crev * 0.15 * (1.0 - per);
    s.rough = sat(0.92 - wet * 0.35 - per * 0.05);
    s.ao = 1.0 - crev * 0.5 * (1.0 - per);
    s.metal = 0.0; s.alpha = 1.0;
    return s;
}
"""#
