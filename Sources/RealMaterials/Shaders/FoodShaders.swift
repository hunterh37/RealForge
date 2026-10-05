// Food programs (cooking simulator ingredients): fruit and vegetable skins, papery onion and garlic
// skins, root skins, radial cross sections for cut faces (centered at uv 0.5), raw poultry, smooth
// solids (butter, chocolate, yolk, end-grain meat, pith, batter) and cooked/baked surfaces.
// Skins come from FoodMesh lofts: u runs around the item, v along its axis (stem to blossom).

let metalFood = #"""
// ---------------------------------------------------------------- food
// Fraction of the way between two values, clamped (inverse lerp).
inline float fdStep(float a, float b, float x) { return sat((x - a) / (b - a)); }
// Thin radial lines: N spokes around the angle fraction `an` (0..1), `w` half-width in spoke units.
inline float fdRays(float an, float N, float w, float jitter) {
    float f = fract(an * N + jitter);
    return 1.0 - smoothstep(w * 0.5, w, min(f, 1.0 - f));
}

// Fruit and vegetable skin. colorA base, colorB blush or shade, colorC speckle (a = strength).
// f.x speckle cells per tile, f.y blush amount, f.z roughness, f.w mode:
// 0 bell pepper (gloss, long waviness, faint stomata), 1 tomato (gloss, pale micro specks, shoulder
// streaks), 2 citrus (oil-gland pits), 3 strawberry (achenes in pits), 4 eggshell (pores, speckles).
S fruitSkin(float2 uv, constant RFParams &P) {
    S s = defaults(); uint sd = P.seed;
    int mode = int(P.f.w + 0.5);
    int F = max(4, int(P.f.x));
    float macro = fbm(uv, int2(3, 3), 4, sd + 1u);
    float mid = fbm(uv, int2(12, 12), 3, sd + 2u);
    float fine = fbm(uv, int2(64, 64), 2, sd + 3u);
    float blush = sat(smoothstep(-0.2, 0.35, macro + 0.15 * mid) * P.f.y);
    float3 c = mix(P.colorA.rgb, P.colorB.rgb, blush);
    c *= 0.95 + 0.06 * mid + 0.03 * fine;
    float h = 0.5 + 0.03 * mid;
    float rough = P.f.z * (0.9 + 0.25 * fine);
    float ao = 1.0;
    if (mode == 0) {
        // Pepper: glassy cuticle with long gentle ripples along v and tiny stomata.
        float ripple = fbm(float2(uv.x, uv.y * 0.25), int2(10, 1), 3, sd + 4u);
        c *= 0.96 + 0.08 * ripple;
        h += ripple * 0.08;
        float4 w = worley(uv, int2(F, F), sd + 5u, 0.9);
        float dot_ = (1.0 - smoothstep(0.04, 0.1, w.x)) * step(0.5, w.z);
        c = mix(c, P.colorC.rgb, dot_ * P.colorC.a);
        rough *= 0.85 + 0.3 * smoothstep(0.1, 0.5, fbm(uv, int2(5, 5), 3, sd + 6u));
    } else if (mode == 1) {
        // Tomato: tight glossy skin, pale micro specks, faint green-yellow shoulder streaks along v.
        float4 w = worley(uv, int2(F, F), sd + 5u, 1.0);
        float speck = (1.0 - smoothstep(0.05, 0.14, w.x)) * step(0.35, w.z);
        c = mix(c, P.colorC.rgb, speck * P.colorC.a);
        float streak = gnoise(float2(uv.x * 40.0, uv.y * 2.0), int2(40, 2), sd + 7u);
        c *= 0.97 + 0.06 * streak;
        h += speck * 0.03 + streak * 0.02;
    } else if (mode == 2) {
        // Citrus: dense oil-gland pits with darker rims and a waxy sheen between them.
        float4 w = worley(uv, int2(F, F), sd + 5u, 0.85);
        float pit = 1.0 - smoothstep(0.0, 0.32, w.x);
        float rim = smoothstep(0.18, 0.32, w.x) * (1.0 - smoothstep(0.32, 0.5, w.x));
        float4 w2 = worley(uv, int2(F * 2, F * 2), sd + 8u, 0.9);
        float pit2 = 1.0 - smoothstep(0.0, 0.3, w2.x);
        c = mix(c, P.colorC.rgb, sat(pit * 0.35 + pit2 * 0.15) * P.colorC.a);
        c *= 1.0 + rim * 0.05;
        h += -pit * 0.18 - pit2 * 0.06 + rim * 0.03;
        ao = 1.0 - pit * 0.25;
        rough = rough * (0.85 + pit * 0.4);
    } else if (mode == 3) {
        // Strawberry: achenes seated in pits on a hex-like lattice, rims slightly lighter.
        float cid = 0.0, cid2 = 0.0;
        float2 off = cellLocal(uv, int2(F, F), sd + 9u, cid, cid2);
        float2 q = off * float2(1.0, 1.35);
        float d = length(q);
        float pit = 1.0 - smoothstep(0.12, 0.3, d);
        float seed = 1.0 - smoothstep(0.07, 0.1, length(q * float2(1.15, 0.7) - float2(0.0, 0.02)));
        float3 seedCol = mix(P.colorC.rgb, P.colorC.rgb * float3(1.0, 0.55, 0.35), cid2 * 0.8);
        c = mix(c, P.colorB.rgb * 0.55, pit * 0.7);
        c = mix(c, seedCol, seed);
        h += -pit * 0.25 + seed * 0.2;
        ao = 1.0 - pit * 0.45 * (1.0 - seed);
        rough = mix(rough, 0.45, seed);
    } else {
        // Eggshell: matte calcite with fine pores, mottled tone, scattered pigment speckles.
        float4 w = worley(uv, int2(F, F), sd + 5u, 1.0);
        float pore = (1.0 - smoothstep(0.02, 0.07, w.x)) * step(0.4, w.z);
        float4 sp = worley(uv, int2(F / 6, F / 6), sd + 10u, 1.0);
        float spot = (1.0 - smoothstep(0.05 + 0.12 * sp.w, 0.1 + 0.2 * sp.w, sp.x)) * step(0.55, sp.z);
        float4 sp2 = worley(uv, int2(F / 2, F / 2), sd + 11u, 1.0);
        float fleck = (1.0 - smoothstep(0.04, 0.1, sp2.x)) * step(0.7, sp2.z);
        c = mix(c, P.colorC.rgb, sat(spot * 0.7 + fleck * 0.5) * P.colorC.a);
        c *= 1.0 - pore * 0.15;
        h += fine * 0.05 - pore * 0.1;
        rough = P.f.z * (0.92 + 0.15 * fine) + pore * 0.1;
    }
    s.albedo = c; s.height = h; s.rough = clamp(rough, 0.06, 1.0); s.ao = ao;
    return s;
}

// Papery dry skin (onion, shallot, garlic): parallel veins along v, darker streaks, flaking patches
// showing a paler layer, soil blemishes. colorA base, colorB vein and streak, colorC flake layer
// (a = flake amount). f.x veins across u per tile, f.y tears and creases, f.z roughness, f.w mode
// (0 onion copper, 1 garlic with purple streaks from colorB).
S papery(float2 uv, constant RFParams &P) {
    S s = defaults(); uint sd = P.seed;
    int F = max(8, int(P.f.x));
    float warp = fbm(uv, int2(3, 2), 3, sd + 1u) * 0.03;
    float x = uv.x + warp;
    float veins = gnoise(float2(x * float(F), uv.y * 2.0), int2(F, 2), sd + 2u);
    float vline = smoothstep(0.25, 0.55, abs(veins));
    float fineV = gnoise(float2(x * float(F) * 5.0, uv.y * 3.0), int2(F * 5, 3), sd + 3u);
    float streak = smoothstep(0.0, 0.5, fbm(float2(x, uv.y * 0.2), int2(14, 1), 3, sd + 4u));
    float macro = fbm(uv, int2(4, 4), 4, sd + 5u);
    float3 c = P.colorA.rgb * (0.9 + 0.12 * macro + 0.05 * fineV);
    c = mix(c, P.colorB.rgb, sat((1.0 - vline) * 0.22 + streak * 0.3));
    c *= 1.0 + 0.08 * smoothstep(0.3, 0.6, fineV);
    if (int(P.f.w + 0.5) == 1) {
        // Garlic: ivory paper with fine purple-brown streaks fanning along v.
        float purple = smoothstep(0.15, 0.45, fbm(float2(x, uv.y * 0.3), int2(9, 1), 4, sd + 6u));
        c = mix(P.colorA.rgb * (0.95 + 0.08 * fineV), P.colorB.rgb, purple * 0.55 + vline * 0.12);
    }
    // Flaking: torn patches where the outer layer is gone and the paler inner layer shows.
    float flakeN = fbm(float2(x, uv.y), int2(6, 2), 4, sd + 7u) + 0.08 * fineV;
    float flake = smoothstep(0.2, 0.23, flakeN) * P.colorC.a;
    float edge = (smoothstep(0.17, 0.2, flakeN) - smoothstep(0.2, 0.23, flakeN)) * P.colorC.a;
    c = mix(c, P.colorC.rgb * (0.95 + 0.1 * fineV), flake);
    c *= 1.0 - edge * 0.25 * P.colorC.a;
    // Creases and tears: thin dark lines across the veins.
    float crease = smoothstep(0.9, 0.97, ridged(uv, int2(4, 6), 3, sd + 8u)) * P.f.y;
    c *= 1.0 - crease * 0.35;
    // Soil blemishes.
    float4 w = worley(uv, int2(9, 9), sd + 9u, 1.0);
    float soil = (1.0 - smoothstep(0.02, 0.12, w.x)) * step(0.93, w.z);
    c = mix(c, P.colorB.rgb * 0.5, soil * 0.45);
    s.albedo = c;
    s.height = 0.5 + 0.05 * fineV + 0.04 * (1.0 - vline) - flake * 0.04 + edge * 0.06 - crease * 0.05;
    s.rough = clamp(P.f.z * (0.9 + 0.2 * streak) - (1.0 - vline) * 0.05, 0.2, 1.0);
    s.ao = 1.0 - crease * 0.3 - edge * 0.15;
    return s;
}

// Root and tuber skin. colorA base, colorB shade and soil, colorC lenticel scar (a = amount).
// f.x lenticel rows per tile along v, f.y soil amount, f.z roughness, f.w mode:
// 0 carrot (transverse lenticel dashes, root-hair scars, fine longitudinal grain),
// 1 russet potato (corky netted skin, lenticel dots, shallow eyes come from geometry).
S rootSkin(float2 uv, constant RFParams &P) {
    S s = defaults(); uint sd = P.seed;
    int F = max(4, int(P.f.x));
    float macro = fbm(uv, int2(3, 3), 4, sd + 1u);
    float mid = fbm(uv, int2(16, 16), 3, sd + 2u);
    float3 c = P.colorA.rgb * (0.93 + 0.1 * macro + 0.05 * mid);
    float h = 0.5, rough = P.f.z, ao = 1.0;
    if (int(P.f.w + 0.5) == 0) {
        float grain = gnoise(float2(uv.x * 60.0, uv.y * 3.0), int2(60, 3), sd + 3u);
        c *= 0.97 + 0.06 * grain;
        // Lenticels: short pale-edged transverse dashes in loose rows along the root.
        float cid = 0.0, cid2 = 0.0;
        float2 off = cellLocal(uv, int2(max(4, F / 3), F), sd + 4u, cid, cid2);
        float2 q = off * float2(1.0, 3.2);
        q.y += q.x * q.x * (cid2 - 0.5) * 1.2;
        float L = 0.35 + 0.4 * cid;
        float dash = (1.0 - smoothstep(L * 0.6, L, abs(q.x))) * (1.0 - smoothstep(0.08, 0.2, abs(q.y)));
        dash *= step(0.25, cid2);
        float lip = (1.0 - smoothstep(L * 0.7, L * 1.1, abs(q.x))) * (smoothstep(0.12, 0.2, abs(q.y)) - smoothstep(0.2, 0.32, abs(q.y))) * step(0.25, cid2);
        c = mix(c, P.colorB.rgb, dash * 0.3 * P.colorC.a);
        c = mix(c, P.colorC.rgb, lip * 0.5 * P.colorC.a);
        h += -dash * 0.3 + lip * 0.12 + grain * 0.03;
        ao -= dash * 0.35;
        // Root-hair scars: tiny dark pits, mostly sitting on lenticel rows.
        float4 w = worley(uv, int2(F, F * 2), sd + 5u, 1.0);
        float scar = (1.0 - smoothstep(0.03, 0.08, w.x)) * step(0.7, w.z);
        c = mix(c, P.colorB.rgb * 0.6, scar * 0.7);
        h -= scar * 0.12;
        rough += dash * 0.1;
    } else {
        // Russet: raised corky net over a smoother tan skin, lenticel dots, scuffs.
        float net = ridged(uv, int2(F * 2, F * 2), 3, sd + 6u);
        float cork = smoothstep(0.6, 0.85, net);
        c = mix(c, P.colorB.rgb * 1.1, cork * 0.25);
        c *= 0.95 + 0.08 * fbm(uv, int2(48, 48), 2, sd + 7u);
        float4 w = worley(uv, int2(F * 2, F * 2), sd + 8u, 1.0);
        float dot_ = (1.0 - smoothstep(0.04, 0.12, w.x)) * step(0.6, w.z);
        c = mix(c, P.colorC.rgb, dot_ * 0.6 * P.colorC.a);
        h += cork * 0.12 + dot_ * 0.05 + mid * 0.04;
        ao -= (1.0 - cork) * 0.08;
        float scuff = smoothstep(0.3, 0.42, fbm(uv, int2(6, 6), 3, sd + 9u));
        c = mix(c, P.colorA.rgb * float3(1.15, 1.08, 0.95), scuff * 0.35);
    }
    float soil = smoothstep(0.1, 0.5, fbm(uv, int2(5, 5), 4, sd + 10u) + 0.1 * mid) * P.f.y;
    c = mix(c, P.colorB.rgb * 0.5, soil * 0.6);
    s.albedo = c; s.height = h; s.rough = clamp(rough + soil * 0.15, 0.15, 1.0); s.ao = sat(ao);
    return s;
}

// Radial cross sections for cut faces, centered at uv 0.5 (r = 1 at the tile edge). colorA main
// flesh, colorB second tissue, colorC detail (a = strength). f.x structure count (rings, locules,
// segments, cloves), f.y detail amount, f.z roughness, f.w mode:
// 0 onion rings, 1 carrot core (xylem star), 2 carrot cortex (phloem rays, cambium ring),
// 3 tomato (pericarp, septa, gel locules, seeds, columella), 4 citrus segments (juice vesicles),
// 5 potato (vascular ring, pith), 6 strawberry (pith, vascular strands to achenes), 7 garlic cloves.
S radialFlesh(float2 uv, constant RFParams &P) {
    S s = defaults(); uint sd = P.seed;
    int mode = int(P.f.w + 0.5);
    float2 p = (uv - 0.5) * 2.0;
    float r = length(p);
    float a = atan2(p.y, p.x);
    float an = (a + 3.14159265) / 6.2831853;   // 0..1
    float N = max(2.0, P.f.x);
    float fine = fbm(uv, int2(48, 48), 3, sd + 1u);
    float mid = fbm(uv, int2(10, 10), 3, sd + 2u);
    float3 c = P.colorA.rgb;
    float h = 0.5, rough = P.f.z, ao = 1.0;
    if (mode == 0) {
        // Onion: fleshy scales as concentric rings, each with a bright inner epidermis line, a
        // translucent body and a faint green cast toward the core.
        float wob = gnoise(float2(an * 7.0, r * 3.0), int2(7, 3), sd + 3u) * 0.04;
        float rr = r + wob;
        float t = rr * N;
        float k = floor(t), f = t - k;
        float line = 1.0 - smoothstep(0.0, 0.07, min(f, 1.0 - f));
        float body = smoothstep(0.08, 0.5, f) * (1.0 - smoothstep(0.5, 0.95, f));
        float vary = h01(int2(int(k), 3), sd + 4u);
        c = mix(P.colorB.rgb, P.colorA.rgb, sat(rr * 1.3));
        c *= 0.9 + 0.12 * vary + 0.06 * body + 0.03 * fine;
        c = mix(c, P.colorC.rgb, line * P.colorC.a);
        // Radial vascular streaks within scales.
        float vasc = smoothstep(0.75, 0.95, gnoise(float2(an * 160.0, rr * 4.0), int2(160, 4), sd + 5u) + 0.5);
        c = mix(c, P.colorC.rgb, vasc * 0.12 * P.f.y);
        // Core: the innermost tight leaves.
        float core = 1.0 - smoothstep(0.0, 0.08, rr);
        c = mix(c, P.colorB.rgb * float3(0.95, 1.05, 0.85), core * 0.6);
        h = 0.5 + body * 0.06 - line * 0.1;
        ao = 1.0 - line * 0.12;
        rough = P.f.z * (1.0 + line * 0.6);
    } else if (mode == 1 || mode == 2) {
        // Carrot. Core: pale xylem with a star of rays; cortex: orange phloem with fine rays and a
        // darker cambium line at the inside edge (r in units of the tile radius).
        float jit = gnoise(float2(an * 8.0, r * 3.0), int2(8, 3), sd + 6u) * 0.25;
        float rayLine = fdRays(an, N, 0.12 + 0.1 * r, jit) * smoothstep(0.08, 0.3, r);
        float fineRay = fdRays(an, N * 4.0, 0.18, jit * 2.0 + gnoise(float2(an * 32.0, r * 6.0), int2(32, 6), sd + 7u) * 0.3) * smoothstep(0.15, 0.4, r);
        if (mode == 1) {
            c = mix(P.colorB.rgb, P.colorA.rgb, smoothstep(0.0, 0.85, r));
            c = mix(c, P.colorB.rgb * 1.1, rayLine * 0.45 * P.f.y);
            c *= 0.96 + 0.05 * fine + 0.04 * fineRay;
            float pith = 1.0 - smoothstep(0.0, 0.1, r);
            c = mix(c, P.colorB.rgb * 1.08, pith * 0.5);
            float edge = smoothstep(0.86, 0.98, r);
            c = mix(c, P.colorC.rgb, edge * 0.6);
        } else {
            c = P.colorA.rgb * (0.95 + 0.05 * mid + 0.03 * fine);
            c = mix(c, P.colorB.rgb, fineRay * 0.25 * P.f.y);
            c = mix(c, P.colorA.rgb * 1.12, rayLine * 0.2 * P.f.y);
            float rim = smoothstep(0.95, 1.0, r);
            c = mix(c, P.colorC.rgb, rim * 0.5);
        }
        h = 0.5 + rayLine * 0.03 + fineRay * 0.02;
        rough = P.f.z * (0.95 + 0.1 * fine);
    } else if (mode == 3) {
        // Tomato: thick pericarp wall, N septa to the columella, gel-filled locules with seeds.
        float wall0 = 0.72;
        float seg = an * N + gnoise(float2(r * 2.0, an * 4.0), int2(2, 4), sd + 8u) * 0.15;
        float sf = fract(seg);
        float sept = 1.0 - smoothstep(0.03, 0.09, min(sf, 1.0 - sf));
        float col = 1.0 - smoothstep(0.12, 0.26, r + 0.04 * gnoise(float2(an * 5.0, 0.5), int2(5, 1), sd + 16u));
        float wall = smoothstep(wall0 - 0.03, wall0 + 0.02, r);
        float locule = (1.0 - wall) * (1.0 - col) * (1.0 - sept);
        float3 flesh = P.colorA.rgb * (0.94 + 0.08 * mid + 0.04 * fine);
        float3 gel = mix(P.colorB.rgb, P.colorA.rgb, sat(0.3 + 0.6 * mid)) * (0.9 + 0.25 * fine);
        c = mix(flesh, gel, locule);
        c = mix(c, mix(P.colorA.rgb, float3(0.9, 0.55, 0.45), 0.35), col * 0.6);
        // Vascular dots in the pericarp.
        float4 vw = worley(uv, int2(20, 20), sd + 9u, 1.0);
        float vdot = (1.0 - smoothstep(0.03, 0.09, vw.x)) * wall * step(0.75, vw.z);
        c = mix(c, P.colorC.rgb * 0.9 + P.colorA.rgb * 0.1, vdot * 0.4);
        float skin = smoothstep(0.96, 1.0, r);
        c = mix(c, P.colorA.rgb * 0.7, skin);
        // Seeds: pale flattened ovals in each locule, near the inner wall around the placenta.
        float cid = 0.0, cid2 = 0.0;
        float2 off = cellLocal(uv, int2(14, 14), sd + 10u, cid, cid2);
        float2 q = rot2(off, cid * 6.28);
        float seed = 1.0 - smoothstep(0.2, 0.27, length(q * float2(1.0, 1.7)));
        float seedZone = locule * smoothstep(0.25, 0.32, r) * (1.0 - smoothstep(0.55, 0.65, r)) * step(0.35, cid2);
        float halo = (1.0 - smoothstep(0.24, 0.4, length(q * float2(1.0, 1.8)))) * seedZone;
        c = mix(c, P.colorB.rgb * 1.15, halo * 0.3);
        c = mix(c, P.colorC.rgb, seed * seedZone);
        h = 0.5 + wall * 0.08 + sept * 0.06 - locule * 0.06 + seed * seedZone * 0.1;
        rough = mix(P.f.z * 1.6, P.f.z * 0.5, locule);
        ao = 1.0 - locule * 0.15;
    } else if (mode == 4) {
        // Citrus: N wedge segments, white membranes, radial juice vesicles, central pith.
        float seg = an * N;
        float sf = fract(seg);
        float k = floor(seg);
        float memb = 1.0 - smoothstep(0.0, 0.02 / max(r, 0.15), min(sf, 1.0 - sf));
        float pithC = 1.0 - smoothstep(0.08, 0.14, r);
        float outer = smoothstep(0.96, 0.99, r);
        // Vesicles: teardrops elongated along r, in cells of angle x radius.
        float4 w = worley(float2(sf, r), int2(5, 5), sd + 11u + uint(k) * 13u, 0.8);
        float ves = smoothstep(0.0, 0.25, w.y - w.x);
        float glint = 1.0 - smoothstep(0.0, 0.25, w.x);
        float3 juice = P.colorA.rgb * (0.8 + 0.2 * ves + 0.12 * glint + 0.05 * fine);
        c = mix(juice, P.colorC.rgb, sat(memb + pithC + outer));
        c = mix(c, mix(P.colorB.rgb, P.colorC.rgb, 0.5), (1.0 - ves) * 0.3 * (1.0 - memb));
        h = 0.5 + ves * 0.08 - memb * 0.05;
        rough = mix(P.f.z * 0.6, 0.7, sat(memb + pithC + outer));
        ao = 1.0 - (1.0 - ves) * 0.2;
    } else if (mode == 5) {
        // Potato: creamy parenchyma, faint vascular ring, translucent star-shaped pith.
        c = P.colorA.rgb * (0.95 + 0.06 * mid + 0.03 * fine);
        float ringR = 0.78 + 0.05 * gnoise(float2(an * 5.0, 0.5), int2(5, 1), sd + 12u);
        float ring = 1.0 - smoothstep(0.0, 0.025, abs(r - ringR));
        c = mix(c, P.colorC.rgb, ring * 0.5 * P.f.y);
        float star = 0.25 + 0.12 * sin(a * 5.0 + mid * 2.0);
        float pith = 1.0 - smoothstep(star - 0.08, star + 0.05, r);
        c = mix(c, P.colorB.rgb, pith * 0.4);
        float4 w = worley(uv, int2(80, 80), sd + 13u, 1.0);
        float starch = (1.0 - smoothstep(0.0, 0.12, w.x)) * step(0.7, w.z);
        c *= 1.0 + starch * 0.05;
        h = 0.5 + fine * 0.03;
        rough = P.f.z * (0.9 + 0.2 * fine);
    } else if (mode == 6) {
        // Strawberry: white pith, pale vascular strands radiating to the achenes, deepening red.
        float pr = length(p * float2(1.0, 0.8));
        float pith = 1.0 - smoothstep(0.2, 0.3, pr + 0.04 * mid);
        float jit = gnoise(float2(an * 6.0, r * 2.0), int2(6, 2), sd + 14u) * 0.3;
        float strands = fdRays(an, N, 0.025 + 0.03 * r, jit * 0.4) * smoothstep(0.2, 0.35, r) * (1.0 - smoothstep(0.85, 0.97, r));
        c = mix(P.colorA.rgb, P.colorB.rgb, smoothstep(0.3, 1.0, r));
        c = mix(c, mix(P.colorA.rgb, P.colorC.rgb, 0.5), (1.0 - smoothstep(0.25, 0.5, pr)) * 0.5);
        c = mix(c, P.colorC.rgb, sat(pith * 0.85 + strands * 0.35));
        c *= 0.93 + 0.08 * mid + 0.04 * fine;
        h = 0.5 + fine * 0.04;
        rough = P.f.z * (1.0 - pith * 0.2);
    } else {
        // Garlic: N cloves arranged around a basal stem, each a rounded wedge in thin paper.
        float seg = an * N;
        float sf = fract(seg);
        float k = floor(seg);
        float off = h01(int2(int(k), 5), sd + 15u) * 0.06;
        float inR = 0.1 + off * 0.5, outR = 0.97 - off;
        float rc = (inR + outR) * 0.5, L = (outR - inR) * 0.5;
        float W = 3.14159265 * max(r, 0.05) / N * 0.94;
        float across = (sf - 0.5) * r * 6.2831853 / N;
        float d = pow(pow(abs(r - rc) / L, 4.0) + pow(abs(across) / W, 4.0), 0.25);
        float inside = 1.0 - smoothstep(0.93, 1.0, d);
        float3 clove = P.colorA.rgb * (0.95 + 0.05 * mid + 0.03 * fine);
        float bud = 1.0 - smoothstep(0.0, 0.05, length(float2(across * 1.8, r - rc * 0.9)));
        clove = mix(clove, P.colorB.rgb, bud * 0.6);
        c = mix(P.colorC.rgb, clove, inside);
        h = 0.5 + inside * 0.08;
        rough = mix(0.75, P.f.z, inside);
        ao = 1.0 - (1.0 - inside) * 0.3;
    }
    s.albedo = c; s.height = h; s.rough = clamp(rough, 0.05, 1.0); s.ao = sat(ao);
    return s;
}

// Raw poultry breast surface: pale pink translucent muscle with fiber striations along v, white fat
// striations, silverskin patches (pearly film with wavy fibers), a few small vessels; wet sheen as
// roughness dips. colorA muscle, colorB deep tone, colorC fat and silverskin (a = film amount).
// f.x fibers across u per tile, f.y fat striation, f.z roughness, f.w fiber angle (radians).
S poultryFlesh(float2 uv, constant RFParams &P) {
    S s = defaults(); uint sd = P.seed;
    float2 r = rot2(uv, P.f.w);
    int F = max(4, int(P.f.x));
    float macro = fbm(uv, int2(3, 3), 4, sd + 1u);
    float fib = gnoise(float2(r.x * float(F), r.y * 2.0), int2(F, 2), sd + 2u);
    float fib2 = gnoise(float2(r.x * float(F) * 4.0, r.y * 4.0), int2(F * 4, 4), sd + 3u);
    float fl = smoothstep(0.1, 0.45, abs(gnoise(float2(r.x * float(F) * 3.0, r.y * 6.0), int2(F * 3, 6), sd + 12u)));
    float3 c = mix(P.colorA.rgb, P.colorB.rgb, sat(0.35 + macro * 0.8 + fib * 0.3));
    c *= 0.93 + 0.07 * fib2 + 0.06 * fl;
    // Fat striation: thin white lines along fibers, broken.
    float fatL = 1.0 - smoothstep(0.0, 0.06, abs(gnoise(float2(r.x * float(F) * 0.5, r.y * 1.0), int2(max(1, F / 2), 1), sd + 5u)));
    float fatGate = smoothstep(0.05, 0.3, fbm(float2(r.x, r.y * 0.5), int2(6, 3), 3, sd + 6u));
    float fat = fatL * fatGate * P.f.y;
    c = mix(c, P.colorC.rgb, fat * 0.55);
    // Silverskin: pearly translucent film in streaks along the fibers.
    float film = smoothstep(0.15, 0.35, fbm(float2(r.x * 2.0, r.y * 0.5), int2(8, 1), 4, sd + 7u)) * P.colorC.a;
    float wav = gnoise(float2(r.x * float(F) * 2.0, r.y * 3.0), int2(F * 2, 3), sd + 8u);
    c = mix(c, P.colorC.rgb * (0.9 + 0.12 * wav), film * 0.4);
    // Small vessels: thin dark-red branching lines.
    float v = ridged(uv, int2(3, 3), 4, sd + 9u);
    float vessel = smoothstep(0.9, 0.97, v) * 0.6;
    c = mix(c, P.colorB.rgb * float3(0.75, 0.35, 0.4), vessel * 0.5);
    // Blood spot.
    float4 w = worley(uv, int2(3, 3), sd + 10u, 1.0);
    float spot = (1.0 - smoothstep(0.05, 0.16, w.x)) * step(0.85, w.z);
    c = mix(c, P.colorB.rgb * float3(0.9, 0.6, 0.62), spot * 0.18);
    s.albedo = c;
    s.height = 0.5 + 0.05 * fib + 0.012 * fib2 + 0.008 * fl + film * 0.02 + fat * 0.015;
    float wet = smoothstep(-0.1, 0.3, fbm(uv, int2(5, 5), 3, sd + 11u));
    s.rough = clamp(P.f.z * (0.6 + 0.6 * wet) * (1.0 - film * 0.3), 0.08, 1.0);
    s.ao = 1.0;
    return s;
}

// Smooth food solids. colorA base, colorB variation, colorC detail (a = amount). f.x detail cells
// per tile, f.y detail amount, f.z roughness, f.w mode: 0 plant parenchyma (cell sparkle, faint
// strands), 1 butter (soft streaks, tiny pits), 2 chocolate (gloss, faint bloom, scratches),
// 3 yolk (membrane mottle), 4 albumen, 5 meat end grain (fascicle cells, pale septa, fat flecks),
// 6 spongy pith (pores), 7 batter (bubbles, flour specks).
S foodSmooth(float2 uv, constant RFParams &P) {
    S s = defaults(); uint sd = P.seed;
    int mode = int(P.f.w + 0.5);
    int F = max(4, int(P.f.x));
    float macro = fbm(uv, int2(3, 3), 4, sd + 1u);
    float mid = fbm(uv, int2(12, 12), 3, sd + 2u);
    float fine = fbm(uv, int2(64, 64), 2, sd + 3u);
    float3 c = mix(P.colorA.rgb, P.colorB.rgb, sat(0.5 + macro));
    float h = 0.5, rough = P.f.z, ao = 1.0;
    if (mode == 0) {
        float4 w = worley(uv, int2(F, F), sd + 4u, 0.9);
        float wallL = 1.0 - smoothstep(0.0, 0.08, w.y - w.x);
        c *= 0.96 + 0.06 * w.z;
        c = mix(c, P.colorC.rgb, wallL * 0.25 * P.f.y);
        float strand = smoothstep(0.85, 0.95, ridged(float2(uv.x, uv.y), int2(3, 6), 3, sd + 5u));
        c = mix(c, P.colorC.rgb, strand * 0.2 * P.f.y);
        h += (1.0 - wallL) * 0.04;
        rough *= 0.9 + 0.2 * wallL;
    } else if (mode == 1) {
        float streak = gnoise(float2(uv.x * 3.0, uv.y * 40.0), int2(3, 40), sd + 6u);
        c *= 0.97 + 0.04 * streak + 0.02 * fine;
        float4 w = worley(uv, int2(F, F), sd + 7u, 1.0);
        float pit = (1.0 - smoothstep(0.03, 0.09, w.x)) * step(0.75, w.z);
        c = mix(c, P.colorC.rgb, pit * 0.3);
        h += streak * 0.02 + fine * 0.02 - pit * 0.12;
        ao -= pit * 0.2;
        rough *= 0.9 + 0.25 * smoothstep(0.0, 0.4, mid);
    } else if (mode == 2) {
        c *= 0.97 + 0.05 * mid;
        float bloom = smoothstep(0.2, 0.5, fbm(uv, int2(4, 4), 4, sd + 8u)) * P.colorC.a;
        c = mix(c, P.colorC.rgb, bloom * 0.3);
        float scratch = smoothstep(0.93, 0.99, ridged(rot2(uv, 0.4), int2(2, 9), 2, sd + 9u)) * P.f.y;
        c = mix(c, P.colorC.rgb, scratch * 0.2);
        h += fine * 0.01 - scratch * 0.03;
        rough = P.f.z * (1.0 + bloom * 1.5 + scratch);
    } else if (mode == 3) {
        float m = smoothstep(-0.2, 0.3, mid);
        c = mix(P.colorA.rgb, P.colorB.rgb, m * 0.35) * (0.97 + 0.04 * fine);
        float spot = smoothstep(0.3, 0.45, fbm(uv, int2(5, 5), 3, sd + 10u));
        c = mix(c, P.colorC.rgb, spot * 0.2 * P.colorC.a);
        h += mid * 0.02;
    } else if (mode == 4) {
        c = mix(P.colorA.rgb, P.colorB.rgb, sat(0.5 + mid * 0.8));
        h += mid * 0.03;
    } else if (mode == 5) {
        float4 w = worley(uv, int2(F, F), sd + 11u, 0.85);
        float sept = 1.0 - smoothstep(0.0, 0.1, w.y - w.x);
        float4 w2 = worley(uv, int2(F * 4, F * 4), sd + 12u, 0.9);
        float fiber = 1.0 - smoothstep(0.0, 0.12, w2.y - w2.x);
        c = mix(P.colorA.rgb, P.colorB.rgb, sat(0.4 + (w.z - 0.5) * 0.25 + macro * 0.7));
        c *= 0.97 + 0.04 * (1.0 - fiber);
        c = mix(c, P.colorC.rgb, sept * 0.18 * P.f.y);
        float4 fw = worley(uv, int2(max(2, F / 4), max(2, F / 4)), sd + 13u, 1.0);
        float fleck = (1.0 - smoothstep(0.02, 0.07, fw.x)) * step(0.9, fw.z);
        c = mix(c, P.colorC.rgb, fleck * 0.4);
        h += -sept * 0.08 - fiber * 0.03;
        ao -= sept * 0.15;
        rough *= 0.8 + 0.4 * sept;
    } else if (mode == 6) {
        float4 w = worley(uv, int2(F, F), sd + 14u, 1.0);
        float pore = 1.0 - smoothstep(0.1, 0.3, w.x);
        c = mix(P.colorA.rgb, P.colorB.rgb, pore * 0.3 + sat(macro) * 0.3);
        float strand = smoothstep(0.85, 0.95, ridged(uv, int2(4, 4), 3, sd + 15u));
        c = mix(c, P.colorC.rgb, strand * 0.3 * P.f.y);
        h += -pore * 0.1;
        ao -= pore * 0.2;
    } else {
        float4 w = worley(uv, int2(F, F), sd + 16u, 1.0);
        float bub = (1.0 - smoothstep(0.05 + 0.08 * w.w, 0.1 + 0.1 * w.w, w.x)) * step(0.55, w.z);
        float ringB = smoothstep(0.05 + 0.08 * w.w, 0.1 + 0.1 * w.w, w.x) * (1.0 - smoothstep(0.1 + 0.1 * w.w, 0.16 + 0.1 * w.w, w.x)) * step(0.55, w.z);
        c *= 0.97 + 0.05 * mid;
        c = mix(c, P.colorB.rgb, bub * 0.25);
        c *= 1.0 + ringB * 0.06;
        float4 fw = worley(uv, int2(F * 2, F * 2), sd + 17u, 1.0);
        float speck = (1.0 - smoothstep(0.02, 0.06, fw.x)) * step(0.8, fw.z);
        c = mix(c, P.colorC.rgb, speck * 0.5 * P.colorC.a);
        h += -bub * 0.15 + ringB * 0.05 + mid * 0.03;
        ao -= bub * 0.2;
        rough *= 1.0 - ringB * 0.3;
    }
    s.albedo = c; s.height = h; s.rough = clamp(rough, 0.05, 1.0); s.ao = sat(ao);
    return s;
}

// Cooked and baked surfaces. colorA cooked base, colorB browned, colorC light highlight (a = amount).
// f.x structure cells per tile, f.y browning, f.z roughness, f.w mode: 0 cooked meat surface
// (fibers along v, seared patches), 1 cooked meat end grain (opaque cells), 2 caramelized soft
// vegetable (translucent amber streaks, gloss), 3 baked crumb (golden crust with pores),
// 4 roasted skin (wrinkles, blistered brown spots), 5 browned butter (milk-solid flecks).
S foodCrumb(float2 uv, constant RFParams &P) {
    S s = defaults(); uint sd = P.seed;
    int mode = int(P.f.w + 0.5);
    int F = max(4, int(P.f.x));
    float macro = fbm(uv, int2(3, 3), 4, sd + 1u);
    float mid = fbm(uv, int2(12, 12), 3, sd + 2u);
    float fine = fbm(uv, int2(64, 64), 2, sd + 3u);
    float brown = smoothstep(-0.1, 0.4, macro + 0.3 * mid) * P.f.y;
    float3 c = mix(P.colorA.rgb, P.colorB.rgb, brown);
    float h = 0.5, rough = P.f.z, ao = 1.0;
    if (mode == 0) {
        float fib = gnoise(float2(uv.x * float(F), uv.y * 2.0), int2(F, 2), sd + 4u);
        float fib2 = gnoise(float2(uv.x * float(F) * 4.0, uv.y * 3.0), int2(F * 4, 3), sd + 5u);
        float split = smoothstep(0.35, 0.5, abs(fib));
        c *= 0.92 + 0.1 * fib2 + 0.04 * fine;
        c = mix(c, P.colorB.rgb * 0.7, split * 0.25);
        h += fib * 0.06 + fib2 * 0.04 - split * 0.08;
        ao -= split * 0.2;
    } else if (mode == 1) {
        float4 w = worley(uv, int2(F, F), sd + 6u, 0.85);
        float sept = 1.0 - smoothstep(0.0, 0.12, w.y - w.x);
        c = mix(P.colorA.rgb * (0.94 + 0.08 * w.z), P.colorC.rgb, sept * 0.25 * P.colorC.a);
        h += -sept * 0.1 + fine * 0.03;
        ao -= sept * 0.2;
    } else if (mode == 2) {
        float streak = gnoise(float2(uv.x * 30.0, uv.y * 2.0), int2(30, 2), sd + 7u);
        c = mix(c, P.colorB.rgb, sat(streak * 0.6 + 0.2) * P.f.y * 0.6);
        c *= 0.95 + 0.08 * fine;
        float glaze = smoothstep(0.0, 0.4, mid);
        rough = P.f.z * (0.6 + 0.6 * (1.0 - glaze));
        h += streak * 0.04;
    } else if (mode == 3) {
        float4 w = worley(uv, int2(F, F), sd + 8u, 1.0);
        float pore = (1.0 - smoothstep(0.08 + 0.15 * w.w, 0.2 + 0.2 * w.w, w.x)) * step(0.35, w.z);
        float4 w2 = worley(uv, int2(F * 3, F * 3), sd + 9u, 1.0);
        float pore2 = (1.0 - smoothstep(0.1, 0.25, w2.x)) * step(0.5, w2.z);
        c *= 0.92 + 0.12 * mid + 0.05 * fine;
        c = mix(c, P.colorB.rgb * 0.75, pore * 0.45 + pore2 * 0.2);
        c = mix(c, P.colorC.rgb, smoothstep(0.2, 0.5, fine) * 0.15 * P.colorC.a);
        h += -pore * 0.25 - pore2 * 0.1 + mid * 0.05;
        ao -= pore * 0.35 + pore2 * 0.15;
    } else if (mode == 4) {
        float wr = ridged(float2(uv.x, uv.y), int2(F, max(2, F / 3)), 3, sd + 10u);
        float wrinkle = smoothstep(0.6, 0.85, wr);
        float4 w = worley(uv, int2(F / 2 + 2, F / 2 + 2), sd + 11u, 1.0);
        float blister = (1.0 - smoothstep(0.1, 0.35, w.x)) * step(0.6, w.z) * P.f.y;
        c = mix(c, P.colorB.rgb * 0.8, blister * 0.6 + wrinkle * 0.15);
        h += wrinkle * 0.1 + blister * 0.05;
        ao -= (1.0 - wrinkle) * 0.05;
    } else {
        float4 w = worley(uv, int2(F, F), sd + 12u, 1.0);
        float fleck = (1.0 - smoothstep(0.04, 0.12, w.x)) * step(0.45, w.z);
        c = mix(c, P.colorB.rgb * 0.6, fleck * 0.8);
        c *= 0.96 + 0.06 * mid;
        h += fleck * 0.05;
        rough = P.f.z * (0.8 + fleck * 0.6);
    }
    s.albedo = c; s.height = h; s.rough = clamp(rough + brown * 0.1, 0.05, 1.0); s.ao = sat(ao);
    return s;
}
"""#
