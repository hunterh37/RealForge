import RealCore

// Insect programs: chitin cuticle, setae (fur), compound eyes, scaled wing and elytron patterns,
// cutout wing venation, monarch caterpillar banding. Wing and elytron programs are atlas maps over a
// normalized wing frame (u root -> tip, v posterior -> anterior/costal edge); the wing outlines come
// from `InsectWings` so margins and bands follow the cut edge.

let metalInsect = InsectWings.metalSource + #"""
// ---------------------------------------------------------------- insects
inline float3 lin3(float3 c) { return pow(c, float3(2.2)); }

// Signed distance to wing outline `id` (negative inside); t = arc parameter (0..1) of the nearest edge.
float wingSD(int id, float2 p, thread float &t) {
    int o = id * WING_N; float d = 1e9; float s = 1.0; t = 0.0;
    for (int i = 0, j = WING_N - 1; i < WING_N; j = i, i++) {
        float2 a = WING_PTS[o + i], b = WING_PTS[o + j];
        float2 e = b - a, w = p - a;
        float h = clamp(dot(w, e) / max(dot(e, e), 1e-8), 0.0, 1.0);
        float2 q = w - e * h;
        float dd = dot(q, q);
        if (dd < d) { d = dd; t = (float(i) - h) / float(WING_N); }
        bool c1 = p.y >= a.y, c2 = p.y < b.y, c3 = e.x * w.y > e.y * w.x;
        if ((c1 && c2 && c3) || (!c1 && !c2 && !c3)) s = -s;
    }
    t = fract(t + 1.0);
    return s * sqrt(d);
}
// Distance from p to segment ab.
inline float segD(float2 p, float2 a, float2 b) {
    float2 pa = p - a, ba = b - a; float h = clamp(dot(pa, ba) / max(dot(ba, ba), 1e-8), 0.0, 1.0);
    return length(pa - ba * h);
}
// Veins radiating from `o` to the margin at angles a0..a1 (count lines); returns distance to nearest.
float rayVeins(float2 p, float2 o, float a0, float a1, int count) {
    float d = 1e9;
    for (int k = 0; k < count; k++) {
        float a = mix(a0, a1, (float(k) + 0.5) / float(count));
        float2 dir = float2(cos(a), sin(a));
        float2 q = p - o; float along = dot(q, dir);
        if (along > 0.0) d = min(d, abs(q.x * dir.y - q.y * dir.x));
    }
    return d;
}
// Lepidopteran venation: a discal cell (ellipse ring) with veins leaving its boundary toward the
// margin, fanned away from `focus` (near the wing root). Returns distance to the nearest vein.
float cellVeins(float2 p, float2 c, float2 r, float2 focus, float a0, float a1, int count) {
    float2 q = (p - c) / r;
    float d = abs(length(q) - 1.0) * min(r.x, r.y);
    for (int k = 0; k < count; k++) {
        float a = mix(a0, a1, (float(k) + 0.5) / float(count));
        float2 o = c + r * float2(cos(a), sin(a));
        float2 dir = normalize(o - focus);
        float2 w = p - o; float along = dot(w, dir);
        if (along > 0.0) d = min(d, abs(w.x * dir.y - w.y * dir.x));
    }
    return d;
}
// Butterfly scale rows: tiny overlapping shingles that catch light.
inline float scales(float2 uv, uint sd) {
    float2 q = float2(uv.x * 220.0, uv.y * 330.0);
    float row = floor(q.y); q.x += fmod(row, 2.0) * 0.5;
    float2 f = fract(q) - 0.5;
    float sc = 1.0 - smoothstep(0.25, 0.5, length(f * float2(1.0, 1.4)));
    return sc * (0.7 + 0.3 * h01(int2(int(floor(q.x)) & 1023, int(row) & 1023), sd));
}

// Chitin cuticle: glossy exoskeleton with punctures (pits), micro-sculpture and a hue shift between
// colorA and colorB (metallic beetles). colorC pit tint. f.x pits per tile, f.y hue shift amount,
// f.z roughness, f.w metalness.
S chitin(float2 uv, constant RFParams &P) {
    S s = defaults(); uint sd = P.seed;
    float macro = fbm(uv, int2(3, 3), 4, sd + 1u);
    float fine = fbm(uv, int2(48, 48), 2, sd + 2u);
    int F = max(4, int(P.f.x));
    float4 w = worley(uv, int2(F, F), sd + 3u, 0.9);
    float pit = (1.0 - smoothstep(0.06, 0.16, w.x)) * step(0.35, w.z);
    float shift = sat(0.5 + macro * 1.6) * P.f.y;
    float3 c = mix(P.colorA.rgb, P.colorB.rgb, shift);
    c *= 0.92 + 0.12 * macro + 0.04 * fine;
    c = mix(c, P.colorC.rgb, pit * 0.5);
    s.albedo = c; s.height = 0.5 + fine * 0.03 - pit * 0.12 + macro * 0.03;
    s.rough = clamp(P.f.z * (0.85 + 0.3 * fine) + pit * 0.15, 0.04, 1.0);
    s.metal = P.f.w * (1.0 - pit * 0.4); s.ao = 1.0 - pit * 0.35;
    return s;
}

// Setae (pile): dense fine hairs along v with dark roots. colorA hair tip, colorB root.
// f.x strands per tile, f.y clumping, f.z roughness.
S insectFur(float2 uv, constant RFParams &P) {
    S s = defaults(); uint sd = P.seed;
    int F = max(8, int(P.f.x));
    float strands = gnoise(float2(uv.x * float(F), uv.y * float(F) * 0.25), int2(F, max(1, F / 4)), sd + 1u) * 0.5 + 0.5;
    float strands2 = gnoise(float2(uv.x * float(F) * 2.0, uv.y * float(F) * 0.5), int2(F * 2, max(1, F / 2)), sd + 2u) * 0.5 + 0.5;
    float clump = fbm(uv, int2(max(2, F / 8), max(2, F / 8)), 3, sd + 3u);
    float h = sat(strands * 0.6 + strands2 * 0.4 + clump * P.f.y);
    s.albedo = mix(P.colorB.rgb, P.colorA.rgb, smoothstep(0.2, 0.8, h));
    s.height = h; s.rough = clamp(P.f.z + (1.0 - h) * 0.1, 0.3, 1.0); s.ao = 0.7 + 0.3 * h;
    return s;
}

// Compound eye: hexagonal ommatidia lenses with dark borders. colorA lens, colorB border.
// f.x facets per tile, f.z roughness.
S compoundEye(float2 uv, constant RFParams &P) {
    S s = defaults(); uint sd = P.seed;
    int F = max(8, int(P.f.x));
    float2 q = uv * float(F); q.x *= 1.1547;
    float row = floor(q.y); q.x += fmod(row, 2.0) * 0.5;
    float2 f = fract(q) - 0.5;
    float r = length(f * float2(1.0, 1.15));
    float lens = 1.0 - smoothstep(0.32, 0.48, r);
    float var = fbm(uv, int2(4, 4), 3, sd + 1u);
    s.albedo = mix(P.colorB.rgb, P.colorA.rgb * (0.9 + 0.2 * var), lens);
    s.height = 0.5 + lens * (0.35 - r * 0.4); s.rough = clamp(P.f.z + (1.0 - lens) * 0.3, 0.05, 1.0);
    s.ao = 0.75 + 0.25 * lens;
    return s;
}

// Scaled wing and elytron patterns over the normalized wing frame. f.x pattern, f.y outline id,
// f.z aspect (chord / span for elytra spot shapes). colorA ground, colorB pattern, colorC accent.
// Patterns: 0 monarch fore, 1 monarch hind, 2 tiger swallowtail fore, 3 hind, 4 blue morpho fore,
// 5 hind, 6 luna fore, 7 luna hind, 8 katydid tegmen, 9 grasshopper tegmen, 10 seven-spot ladybird
// elytron, 11 firefly elytron, 12 jewel beetle elytron, 13 cricket tegmen.
S insectWing(float2 uv, constant RFParams &P) {
    S s = defaults(); uint sd = P.seed;
    int pat = int(P.f.x + 0.5); int oid = int(P.f.y + 0.5);
    float2 p = uv;
    float t; float sdv = (pat <= 9 || pat == 13) ? wingSD(oid, p, t) : -0.5;
    float m = -sdv;                       // distance inside the margin
    float sc = scales(uv, sd);
    float mott = fbm(uv, int2(6, 6), 4, sd + 1u);
    float3 c = P.colorA.rgb; float rough = 0.55; float metal = 0.0; float h = 0.5;
    float3 black = lin3(float3(0.06, 0.05, 0.05)), white = lin3(float3(0.93, 0.92, 0.88));
    if (pat == 0 || pat == 1) {
        // Monarch: orange ground, black veins widening toward the margin, black border with two rows
        // of white dots, black forewing apex with orange and white subapical spots.
        bool fore = pat == 0;
        float vd = fore ? cellVeins(p, float2(0.30, 0.60), float2(0.26, 0.085), float2(0.18, 0.60), 1.5, -1.75, 10)
                        : cellVeins(p, float2(0.26, 0.56), float2(0.22, 0.10), float2(0.16, 0.56), 1.4, -1.8, 9);
        vd = min(vd, segD(p, float2(0.04, fore ? 0.40 : 0.30), fore ? float2(0.70, 0.26) : float2(0.55, 0.06)));
        if (!fore) vd = min(vd, segD(p, float2(0.03, 0.36), float2(0.30, 0.04)));
        float vw = 0.008 + 0.012 * smoothstep(0.25, 0.0, m);
        float vein = 1.0 - smoothstep(vw, vw + 0.004, vd);
        float border = 1.0 - smoothstep(0.065, 0.075, m);
        float apex = fore ? (1.0 - smoothstep(0.30, 0.32, length((p - float2(1.0, 1.0)) * float2(1.0, 1.4)))) : 0.0;
        float costa = fore ? (1.0 - smoothstep(0.035, 0.045, m)) * step(0.82, p.y) : 0.0;
        float blk = max(max(vein, border), max(apex, costa));
        float k = t * (fore ? 30.0 : 34.0);
        float2 dq = float2(fract(k) - 0.5, 0.0);
        float dots1 = (1.0 - smoothstep(0.18, 0.28, length(float2(dq.x, (m - 0.022) * 18.0))));
        float dots2 = (1.0 - smoothstep(0.16, 0.26, length(float2(fract(k + 0.5) - 0.5, (m - 0.05) * 18.0))));
        float sub = fore ? (1.0 - smoothstep(0.018, 0.026, length(float2(fract(p.x * 18.0) - 0.5, (p.y - 0.86) * 18.0) / 18.0)))
                         * step(0.72, p.x) * step(p.x, 0.92) : 0.0;
        float3 orange = fore ? lin3(float3(0.90, 0.42, 0.06)) : lin3(float3(0.92, 0.48, 0.10));
        c = mix(orange * (0.9 + 0.2 * mott), black, blk);
        c = mix(c, white, max(dots1, dots2 * 0.9) * border * step(0.004, m));
        c = mix(c, mix(white, lin3(float3(0.95, 0.6, 0.15)), step(0.84, p.x)), sub * apex);
        h = 0.5 + vein * 0.12;
    } else if (pat == 2 || pat == 3) {
        // Eastern tiger swallowtail: yellow with black tiger stripes, wide black border with yellow
        // lunules; hindwing border with blue scaling and an orange spot at the anal angle.
        bool fore = pat == 2;
        float3 yellow = lin3(float3(0.98, 0.84, 0.25));
        float vd = fore ? cellVeins(p, float2(0.30, 0.62), float2(0.26, 0.09), float2(0.18, 0.62), 1.5, -1.7, 10)
                        : cellVeins(p, float2(0.26, 0.64), float2(0.22, 0.10), float2(0.16, 0.64), 1.4, -1.9, 8);
        float vein = 1.0 - smoothstep(0.006, 0.010, vd);
        float stripes = 0.0;
        if (fore) {
            float x0[4] = {0.06, 0.24, 0.42, 0.58};
            float len0[4] = {0.75, 0.62, 0.45, 0.25};
            float wd[4] = {0.05, 0.05, 0.045, 0.04};
            for (int i = 0; i < 4; i++) {
                float x = x0[i] + (1.0 - p.y) * 0.08;
                float on = (1.0 - smoothstep(wd[i], wd[i] + 0.01, abs(p.x - x))) * step(1.0 - len0[i], p.y);
                stripes = max(stripes, on);
            }
        } else {
            stripes = (1.0 - smoothstep(0.07, 0.08, abs(p.x - (0.05 + (1.0 - p.y) * 0.2)))) * step(p.y, 0.95);
        }
        float bw = fore ? 0.13 : 0.18;
        float border = 1.0 - smoothstep(bw, bw + 0.01, m);
        float base = fore ? (1.0 - smoothstep(0.03, 0.05, p.x)) : 0.0;
        float k = t * (fore ? 26.0 : 22.0);
        float lun = (1.0 - smoothstep(0.2, 0.32, length(float2(fract(k) - 0.5, (m - bw * 0.35) * 12.0)))) ;
        c = mix(yellow * (0.92 + 0.15 * mott), black, max(max(vein, stripes), max(border, base)));
        c = mix(c, yellow, lun * border * step(0.006, m));
        if (!fore) {
            float blue = (1.0 - smoothstep(0.02, 0.05, abs(m - bw * 0.7))) * step(0.25, p.x) * sc;
            c = mix(c, lin3(float3(0.30, 0.45, 0.85)), blue * 0.8 * border);
            float spot = 1.0 - smoothstep(0.035, 0.05, length(p - float2(0.58, 0.32)));
            c = mix(c, lin3(float3(0.95, 0.45, 0.1)), spot);
        }
        h = 0.5 + vein * 0.1;
    } else if (pat == 4 || pat == 5) {
        // Blue morpho: structural blue (metallic, low roughness) with black costa and border, white
        // spots in the forewing border.
        bool fore = pat == 4;
        float3 blue = lin3(float3(0.08, 0.45, 0.98));
        float3 blue2 = lin3(float3(0.25, 0.75, 1.0));
        float vd = fore ? cellVeins(p, float2(0.30, 0.60), float2(0.26, 0.09), float2(0.18, 0.60), 1.5, -1.75, 10)
                        : cellVeins(p, float2(0.26, 0.56), float2(0.22, 0.10), float2(0.16, 0.56), 1.4, -1.8, 9);
        float vein = 1.0 - smoothstep(0.004, 0.008, vd);
        float bw = fore ? 0.12 + 0.12 * smoothstep(0.6, 1.0, p.x) * smoothstep(0.5, 1.0, p.y) : 0.08;
        float border = 1.0 - smoothstep(bw, bw + 0.03, m);
        float costa = fore ? (1.0 - smoothstep(0.05, 0.07, m)) * step(0.85, p.y) : 0.0;
        float base = 1.0 - smoothstep(0.0, 0.12, p.x);
        float blk = max(border, costa);
        float k = t * 22.0;
        float wsp = (1.0 - smoothstep(0.15, 0.3, length(float2(fract(k) - 0.5, (m - bw * 0.5) * 10.0)))) * (fore ? 1.0 : 0.6);
        float3 bl = mix(blue, blue2, sat(mott * 1.5 + 0.4 + sc * 0.2));
        c = mix(bl, lin3(float3(0.04, 0.05, 0.1)), max(blk, base * 0.85));
        c = mix(c, black, vein * 0.5);
        c = mix(c, white, wsp * border * step(0.01, m));
        float blueAmt = (1.0 - blk) * (1.0 - base * 0.85);
        metal = 0.75 * blueAmt; rough = mix(0.6, 0.18, blueAmt); h = 0.5 + sc * 0.08 * blueAmt;
    } else if (pat == 6 || pat == 7) {
        // Luna moth: pale lime green, maroon-purple costal band (forewing), eyespots with yellow,
        // black and maroon rings, yellow-tinted outer margin and long hindwing tails.
        bool fore = pat == 6;
        float3 green = lin3(float3(0.70, 0.88, 0.55));
        float3 yel = lin3(float3(0.92, 0.88, 0.45));
        float3 maroon = lin3(float3(0.42, 0.16, 0.22));
        c = green * (0.92 + 0.16 * mott);
        float margin = 1.0 - smoothstep(0.02, 0.06, m);
        c = mix(c, yel, margin * 0.7);
        float vd = fore ? cellVeins(p, float2(0.28, 0.66), float2(0.24, 0.08), float2(0.17, 0.66), 1.5, -1.7, 9)
                        : cellVeins(p, float2(0.20, 0.70), float2(0.16, 0.08), float2(0.13, 0.70), 1.3, -2.0, 8);
        c = mix(c, green * 0.75, (1.0 - smoothstep(0.004, 0.009, vd)) * 0.6);
        if (fore) {
            float cost = (1.0 - smoothstep(0.035, 0.05, m)) * step(0.80, p.y) * step(p.x, 0.92);
            c = mix(c, maroon, cost);
        } else {
            float tail = smoothstep(0.35, 0.05, p.y);
            c = mix(c, mix(yel, lin3(float3(0.85, 0.65, 0.45)), 0.6), tail * 0.55);
        }
        float2 eo = fore ? float2(0.50, 0.70) : float2(0.34, 0.70);
        float er = length((p - eo) * float2(1.0, 1.25));
        float e1 = 0.045, e2 = 0.06, e3 = 0.072, e4 = 0.085;
        float3 ring = er < e1 ? lin3(float3(0.85, 0.80, 0.55)) : er < e2 ? yel : er < e3 ? black : maroon;
        float ein = 1.0 - smoothstep(e4, e4 + 0.006, er);
        c = mix(c, ring, ein);
        float clear = 1.0 - smoothstep(0.01, 0.025, length((p - eo + float2(0.008, 0.0)) * float2(2.2, 1.0)));
        c = mix(c, lin3(float3(0.75, 0.82, 0.7)), clear * 0.7);
        rough = 0.75; h = 0.5 + sc * 0.06;
    } else if (pat == 8 || pat == 9 || pat == 13) {
        // Leathery tegmina. Katydid: leaf green with a midrib and side veins, a few brown flecks.
        // Grasshopper: olive-brown mottled with dark rectangular spots. Cricket: glossy black-brown
        // with a vein network.
        float mid = abs(p.y - (0.55 + 0.05 * p.x));
        if (pat == 8) {
            c = P.colorA.rgb * (0.9 + 0.2 * mott);
            float rib = 1.0 - smoothstep(0.006, 0.012, mid);
            float side = 1.0 - smoothstep(0.004, 0.008, abs(fract((p.x - mid * 0.9) * 9.0) - 0.5) / 9.0);
            c = mix(c, P.colorB.rgb, max(rib, side * 0.6));
            float fleck = smoothstep(0.62, 0.72, fbm(uv, int2(10, 10), 3, sd + 9u));
            c = mix(c, P.colorC.rgb, fleck * 0.8);
            h = 0.5 + rib * 0.15 + side * 0.06; rough = 0.55;
        } else if (pat == 9) {
            c = mix(P.colorA.rgb, P.colorB.rgb, sat(mott * 1.5 + 0.5));
            float2 q = float2(p.x * 9.0, p.y * 3.0);
            float spots = step(0.55, h01(int2(floor(q)), sd + 4u)) * (1.0 - smoothstep(0.25, 0.4, length(fract(q) - 0.5)));
            c = mix(c, P.colorC.rgb, spots * 0.85);
            float lv = 1.0 - smoothstep(0.003, 0.006, abs(fract(p.y * 7.0) - 0.5) / 7.0);
            c *= 1.0 - lv * 0.2; h = 0.5 + lv * 0.08; rough = 0.6;
        } else {
            c = P.colorA.rgb * (0.85 + 0.25 * mott);
            float4 w = worley(uv, int2(9, 5), sd + 5u, 0.8);
            float net = 1.0 - smoothstep(0.0, 0.06, w.y - w.x);
            c = mix(c, P.colorB.rgb, net * 0.7);
            h = 0.5 + net * 0.15; rough = 0.35;
        }
        float edge = 1.0 - smoothstep(0.0, 0.03, m);
        c = mix(c, c * 0.7, edge);
    } else if (pat == 10) {
        // Seven-spot ladybird elytron (u 0 at the suture, 1 at the outer edge; v 0 rear, 1 front):
        // three black spots plus half the scutellar spot, glossy red.
        float a = max(P.f.z, 0.5);
        float3 red = lin3(float3(0.82, 0.08, 0.04));
        float sp = 0.0;
        float2 cs[3] = {float2(0.56, 0.80), float2(0.56, 0.50), float2(0.46, 0.22)};
        float rs[3] = {0.19, 0.25, 0.19};
        for (int i = 0; i < 3; i++) {
            float wob = 1.0 + 0.06 * gnoise(p * 6.0, int2(6, 6), sd + uint(i));
            sp = max(sp, 1.0 - smoothstep(rs[i] * wob, rs[i] * wob + 0.015, length((p - cs[i]) * float2(1.0, a))));
        }
        sp = max(sp, 1.0 - smoothstep(0.20, 0.215, length((p - float2(0.0, 1.0)) * float2(1.0, a))));
        c = mix(red * (0.95 + 0.1 * mott), black, sp);
        rough = 0.12; h = 0.5 + mott * 0.02;
    } else if (pat == 11) {
        // Firefly (Photinus) elytron: dark grey-brown with pale yellow suture and outer margin.
        float3 dark = lin3(float3(0.16, 0.14, 0.12));
        float3 pale = lin3(float3(0.85, 0.78, 0.45));
        float edge = max(1.0 - smoothstep(0.04, 0.07, p.x), smoothstep(0.86, 0.9, p.x));
        c = mix(dark * (0.9 + 0.2 * mott), pale, edge);
        rough = 0.45;
    } else {
        // Jewel beetle (Chrysochroa): metallic green with a broad red-violet stripe, fine punctures.
        float3 green = lin3(float3(0.15, 0.75, 0.25)), gold = lin3(float3(0.75, 0.75, 0.2));
        float3 red = lin3(float3(0.85, 0.15, 0.25)), violet = lin3(float3(0.45, 0.15, 0.6));
        float st = 1.0 - smoothstep(0.1, 0.14, abs(p.x - 0.5 - 0.04 * sin(p.y * 6.0)));
        float sh = sat(0.5 + mott * 1.8);
        c = mix(mix(green, gold, sh * 0.5), mix(red, violet, sh), st);
        float4 w = worley(uv, int2(28, 40), sd + 6u, 0.8);
        float pit = 1.0 - smoothstep(0.05, 0.14, w.x);
        c *= 1.0 - pit * 0.3; metal = 0.85; rough = 0.22 + pit * 0.1; h = 0.5 - pit * 0.1;
    }
    if (pat <= 7) c *= 0.92 + 0.12 * sc;
    s.albedo = c; s.rough = rough; s.metal = metal; s.height = h;
    return s;
}

// Wing venation (cutout: alpha is the vein network, membrane is a separate transparent surface on
// the same outline). f.x style: 0 dragonfly, 1 damselfly, 2 bee, 3 cicada, 4 beetle hind wing,
// 5 grasshopper/cricket fan. f.y outline id. colorA veins, colorB pterostigma.
S insectVeins(float2 uv, constant RFParams &P) {
    S s = defaults(); uint sd = P.seed;
    int st = int(P.f.x + 0.5); int oid = int(P.f.y + 0.5);
    float2 p = uv; float t;
    float m = -wingSD(oid, p, t);
    float edge = (1.0 - smoothstep(0.006, 0.010, abs(m))) ;
    float v = 0.0; float stig = 0.0;
    if (st == 0 || st == 1) {
        float lines = 1e9;
        float ys[5] = {0.86, 0.80, 0.70, 0.55, 0.40};
        for (int i = 0; i < 5; i++) {
            float y = mix(st == 1 ? 0.52 : ys[i] - 0.06 * float(i == 4), ys[i] - 0.08 * float(i) * 0.3, p.x);
            lines = min(lines, abs(p.y - y));
        }
        v = 1.0 - smoothstep(0.004, 0.007, lines);
        int2 fr = st == 0 ? int2(30, 14) : int2(22, 6);
        float4 w = worley(uv, fr, sd + 1u, st == 0 ? 0.75 : 0.35);
        v = max(v, (1.0 - smoothstep(0.0, st == 0 ? 0.09 : 0.06, w.y - w.x)) * 0.9);
        float node = (1.0 - smoothstep(0.004, 0.008, abs(p.x - 0.5))) * step(0.72, p.y);
        v = max(v, node);
        stig = (1.0 - smoothstep(0.0, 0.01, abs(p.x - 0.86) - 0.035)) * step(0.0, m) * smoothstep(0.08, 0.04, m) * step(0.6, p.y);
    } else if (st == 2) {
        float vd = segD(p, float2(0.0, 0.62), float2(0.55, 0.78));
        vd = min(vd, segD(p, float2(0.0, 0.50), float2(0.62, 0.60)));
        vd = min(vd, segD(p, float2(0.02, 0.40), float2(0.55, 0.32)));
        vd = min(vd, segD(p, float2(0.55, 0.78), float2(0.70, 0.55)));
        vd = min(vd, segD(p, float2(0.62, 0.60), float2(0.55, 0.32)));
        vd = min(vd, segD(p, float2(0.30, 0.70), float2(0.32, 0.36)));
        vd = min(vd, segD(p, float2(0.70, 0.55), float2(0.66, 0.36)));
        v = 1.0 - smoothstep(0.006, 0.010, vd);
        stig = 1.0 - smoothstep(0.02, 0.03, length((p - float2(0.5, 0.84)) * float2(1.0, 2.5)));
    } else if (st == 3) {
        float vd = rayVeins(p, float2(0.0, 0.5), 0.55, -0.45, 6);
        float4 w = worley(uv, int2(6, 4), sd + 2u, 0.4);
        float cells = (1.0 - smoothstep(0.0, 0.05, w.y - w.x)) * step(0.62, p.x);
        v = max(1.0 - smoothstep(0.006, 0.011, vd), cells);
        float cost = (1.0 - smoothstep(0.02, 0.03, m)) * step(0.72, p.y);
        v = max(v, cost);
    } else if (st == 4) {
        float vd = rayVeins(p, float2(0.0, 0.55), 0.35, -0.9, 5);
        v = (1.0 - smoothstep(0.005, 0.009, vd)) * smoothstep(0.95, 0.4, p.x);
        float cost = (1.0 - smoothstep(0.02, 0.03, m)) * step(0.78, p.y) * step(p.x, 0.7);
        v = max(v, cost);
    } else {
        float vd = rayVeins(p, float2(0.0, 0.5), 1.2, -1.3, 14);
        float4 w = worley(uv, int2(16, 16), sd + 3u, 0.6);
        v = max(1.0 - smoothstep(0.004, 0.007, vd), (1.0 - smoothstep(0.0, 0.05, w.y - w.x)) * 0.6);
    }
    float a = max(max(v, edge), stig) * step(-0.004, m);
    s.albedo = mix(P.colorA.rgb, P.colorB.rgb, stig);
    s.alpha = a > 0.5 ? 1.0 : 0.0; s.rough = 0.35; s.height = 0.5 + a * 0.2;
    return s;
}

// Monarch caterpillar banding along v (one tile per body segment): yellow, black and white
// transverse stripes with a fine wrinkled sheen. colorA yellow, colorB black, colorC white.
S caterpillarBands(float2 uv, constant RFParams &P) {
    S s = defaults(); uint sd = P.seed;
    float y = uv.y;
    float3 c;
    if (y < 0.16) c = P.colorB.rgb;
    else if (y < 0.26) c = P.colorC.rgb;
    else if (y < 0.36) c = P.colorB.rgb;
    else if (y < 0.56) c = P.colorA.rgb;
    else if (y < 0.66) c = P.colorB.rgb;
    else if (y < 0.76) c = P.colorC.rgb;
    else if (y < 0.86) c = P.colorB.rgb;
    else c = P.colorC.rgb;
    float wr = gnoise(float2(uv.x * 40.0, uv.y * 16.0), int2(40, 16), sd + 1u);
    float fine = fbm(uv, int2(24, 24), 2, sd + 2u);
    s.albedo = c * (0.93 + 0.1 * fine);
    float crease = smoothstep(0.9, 1.0, abs(fract(y) * 2.0 - 1.0));
    s.height = 0.5 + wr * 0.05 - crease * 0.1; s.rough = 0.45 + 0.1 * fine; s.ao = 1.0 - crease * 0.3;
    return s;
}
"""#
