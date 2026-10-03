// Conifer, palm and desert programs: barkScotsPine, leafPine, leafFir, leafCypress, barkPalm, leafPalm,
// cactusRibs, leafAgave. Atlas programs draw content with v up the card.

let metalConifer = #"""
// ---------------------------------------------------------------- conifer, palm, desert
// Scots pine bark. f.x = 0: lower trunk, thick grey-brown plates over red-brown furrows.
// f.x = 1: upper trunk and limbs, thin orange papery flakes.
S barkScotsPine(float2 uv, constant RFParams &P) {
    S s = defaults(); uint sd = P.seed;
    float2 warp = float2(fbm(uv, int2(3, 2), 3, sd + 1u), fbm(uv, int2(2, 3), 3, sd + 2u)) * 0.06;
    float fine = fbm(uv, int2(48, 24), 3, sd + 5u);
    float big = fbm(uv, int2(3, 2), 4, sd + 8u);
    if (P.f.x < 0.5) {
        float4 w = worley(uv + warp * 1.6, int2(6, 2), sd + 3u, 0.9);
        float edge = w.y - w.x;
        float plate = smoothstep(0.03, 0.38, edge + 0.08 * fine);
        // Plates are stacks of thin scales: fine wavy horizontal layer lines.
        float lay = fract(uv.y * 36.0 + fbm(uv, int2(6, 4), 3, sd + 4u) * 3.0 + w.z * 5.0);
        float layer = smoothstep(0.0, 0.12, lay) * (1.0 - smoothstep(0.85, 1.0, lay));
        s.height = plate * (0.56 + 0.18 * w.z + 0.08 * layer) + fine * 0.1;
        float3 plateCol = mix(P.colorA.rgb, P.colorC.rgb, smoothstep(0.2, 0.9, w.z * 0.55 + big * 0.6 + fine * 0.3));
        plateCol *= (0.8 + 0.3 * fine) * (0.86 + 0.14 * layer);
        float inner = smoothstep(0.16, 0.07, edge) * smoothstep(0.02, 0.07, edge);
        float3 furrowCol = P.colorB.rgb * (0.7 + 0.5 * fine);
        s.albedo = mix(furrowCol, plateCol, smoothstep(0.05, 0.55, plate));
        s.albedo = mix(s.albedo, P.colorB.rgb * 1.6, inner * 0.3);
        s.rough = mix(0.96, 0.88, plate);
        s.ao = mix(0.25, 1.0, smoothstep(0.0, 0.6, s.height));
    } else {
        float4 w = worley(uv + warp * 0.5, int2(8, 20), sd + 6u, 0.9);
        float edge = w.y - w.x;
        float rim = (1.0 - smoothstep(0.0, 0.06, edge)) * step(0.3, w.w);
        float peel = step(0.65, w.z);
        float lift = smoothstep(0.0, 0.5, w.x) * peel;
        float3 base = mix(P.colorA.rgb, P.colorC.rgb, peel * 0.55 + 0.2 * w.w);
        base *= 0.88 + 0.2 * fine + 0.14 * big;
        float grey = smoothstep(0.12, 0.4, fbm(uv, int2(4, 3), 4, sd + 9u)) * 0.4;
        base = mix(base, float3(0.16, 0.13, 0.11), grey * (1.0 - peel));
        s.albedo = base * (1.0 - 0.28 * rim);
        s.height = 0.5 + 0.1 * w.z + 0.16 * lift - 0.2 * rim + fine * 0.06;
        s.rough = 0.78 - 0.08 * peel;
        s.ao = mix(0.6, 1.0, 1.0 - rim);
    }
    return s;
}

// One needle (tapered, slightly curved line) from o along dir. Returns 0..1 cross profile, sets tip fraction.
float cfNeedle(float2 p, float2 o, float2 dir, float L, float w0, float curve, float blunt, thread float &tt) {
    float2 nr = float2(dir.y, -dir.x);
    float2 d = p - o;
    float x = dot(d, dir);
    if (x < 0.0 || x > L) return 0.0;
    tt = x / L;
    float y = dot(d, nr) - curve * tt * tt * L;
    float w = w0 * mix(1.0 - 0.8 * tt * tt, sqrt(max(0.0, 1.0 - pow(tt, 8.0))), blunt);
    float ad = abs(y);
    return ad < w ? 1.0 - ad / w : 0.0;
}

// Pine shoot tip: three brush-like shoots fanning from one twig end, paired twisted needles all along them.
// f.y fascicles per shoot (default 30).
S leafPine(float2 uv, constant RFParams &P) {
    S s = defaults(); s.alpha = 0.0; s.rough = 0.5;
    float g = P.f.z > 0.5 ? P.f.z : 2.0;
    float2 cuv = uv * g; int2 cell = int2(floor(cuv)); float2 p = cuv - floor(cuv);
    uint sd = P.seed + uint(cell.x * 7 + cell.y * 13);
    s.albedo = mix(P.colorA.rgb, P.colorB.rgb, 0.5);
    float best = -1.0;
    int fascicles = int(P.f.y > 0.5 ? P.f.y : 30.0);
    float2 root = float2(0.5, 0.0);
    float2 fork = float2(0.5 + (h01u(sd) - 0.5) * 0.08, 0.3);
    for (int sh = 0; sh < 3; sh++) {
        uint ss = sd + uint(sh) * 1013u;
        float sa = (float(sh) - 1.0) * (0.42 + 0.15 * h01u(ss)) + (h01u(ss + 1u) - 0.5) * 0.2;
        float slen = (sh == 1 ? 0.5 : 0.38) * (0.85 + 0.25 * h01u(ss + 2u));
        float2 o0 = sh == 1 ? root : fork;
        if (sh == 1) slen += fork.y;
        float2 sdir = float2(sin(sa), cos(sa));
        float2 o1 = o0 + sdir * slen;
        // Shoot axis.
        float2 ab = o1 - o0; float hq = clamp(dot(p - o0, ab) / dot(ab, ab), 0.0, 1.0);
        float tw = length(p - (o0 + ab * hq));
        float twr = 0.012 * (1.1 - 0.6 * hq);
        if (tw < twr && best < 0.12) {
            best = 0.12; s.alpha = 1.0;
            s.albedo = mix(float3(0.2, 0.11, 0.05), float3(0.36, 0.2, 0.09), hq) * (0.8 + 0.4 * (1.0 - tw / twr));
            s.height = 0.35; s.rough = 0.8; s.ao = 0.7;
        }
        // Quick reject.
        if (tw > 0.36) continue;
        float t0 = sh == 1 ? 0.45 : 0.08;
        for (int i = 0; i < 48; i++) {
            if (i >= fascicles) break;
            uint ni = ss + 50u + uint(i) * 11u;
            float t = t0 + (1.0 - t0) * (float(i) + h01u(ni)) / float(fascicles);
            float2 o = mix(o0, o1, t);
            float side = (i % 2 == 0) ? -1.0 : 1.0;
            // Needles leave at ~40-75 degrees, closing up toward the bud.
            float spread = (0.55 + 0.75 * h01u(ni + 2u)) * mix(1.0, 0.55, t * t);
            float L = (0.2 + 0.1 * h01u(ni + 3u)) * mix(1.0, 0.85, t);
            float cv = -side * (0.05 + 0.1 * h01u(ni + 4u));
            for (int k = 0; k < 2; k++) {
                float ang = sa + side * spread + (k == 0 ? -0.06 : 0.07);
                float2 dir = float2(sin(ang), cos(ang));
                float tt = 0.0;
                float v = cfNeedle(p, o, dir, L * (k == 0 ? 1.0 : 0.93), 0.0058, cv + (k == 0 ? 0.0 : 0.04), 0.0, tt);
                if (v <= 0.0) continue;
                float depth = h01u(ni + 5u + uint(k)) * 0.8 + 0.2 * (1.0 - abs(float(sh) - 1.0));
                if (depth < best) continue;
                best = depth; s.alpha = 1.0;
                float var = h01u(ni + 6u + uint(k));
                float3 c = mix(P.colorA.rgb, P.colorB.rgb, var);
                float twist = 0.5 + 0.5 * sin(tt * 9.0 + var * 6.0);
                c = mix(c, P.colorC.rgb, twist * 0.45 * (0.5 + 0.5 * var));
                if (tt < 0.05) c = float3(0.2, 0.13, 0.08);       // papery sheath
                c *= 0.72 + 0.3 * tt + 0.1 * v;
                s.albedo = c; s.height = 0.45 + 0.5 * v + 0.05 * depth;
                s.rough = 0.42 + 0.12 * (1.0 - twist);
                s.ao = 0.55 + 0.45 * tt;
            }
        }
    }
    return s;
}

// Flat fir spray: axis, alternate side shoots, two-ranked short blunt needles.
float cfComb(float2 p, float2 a, float2 b, float L, float thick, float ang, float spacing, uint sd, thread float &along, thread float &tipness) {
    float2 ab = b - a; float len = length(ab); float2 t = ab / len; float2 n = float2(-t.y, t.x);
    float2 d = p - a; float s = dot(d, t), r = dot(d, n);
    if (s < -0.02 || s > len + L) return 0.0;
    float side = r >= 0.0 ? 1.0 : -1.0; float ar = abs(r);
    float ta = tan(ang);
    float s0 = s - ar / ta;
    float k = floor(s0 / spacing + 0.5);
    float s1 = k * spacing;
    if (s1 < 0.0 || s1 > len) return 0.0;
    float jit = h01u(uint(int(k) * 2 + (side > 0.0 ? 1 : 0)) + sd);
    float nl = L * (0.8 + 0.3 * jit) * (0.55 + 0.45 * sin(3.14159 * clamp(s1 / len * 0.9 + 0.1, 0.05, 1.0)));
    float dist = abs(s0 - s1) * sin(ang);
    float rr = ar / sin(ang);
    if (rr > nl) return 0.0;
    float u = rr / nl;
    float w = thick * sqrt(max(0.0, 1.0 - pow(u, 6.0)));   // blunt, rounded tips
    along = s1 / len; tipness = u;
    return dist < w ? 1.0 - dist / w : 0.0;
}
S leafFir(float2 uv, constant RFParams &P) {
    S s = defaults(); s.alpha = 0.0; s.rough = 0.45;
    float g = P.f.z > 0.5 ? P.f.z : 2.0;
    float2 cuv = uv * g; int2 cell = int2(floor(cuv)); float2 p = cuv - floor(cuv);
    uint sd = P.seed + uint(cell.x * 7 + cell.y * 13);
    s.albedo = P.colorA.rgb;
    float bend = (h01u(sd) - 0.5) * 0.12;
    float2 a = float2(0.5, 0.02), b = float2(0.5 + bend, 0.95);
    float best = 0.0, along = 0.0, tipness = 0.0, fresh = 0.0;
    float ang = 1.15 + 0.15 * P.f.x;
    float v = cfComb(p, a, b, 0.07, 0.0034, ang, 0.0085, sd, along, tipness);
    if (v > best) { best = v; fresh = smoothstep(0.82, 0.97, along); }
    for (int i = 0; i < 10; i++) {
        float t = 0.06 + 0.085 * float(i);
        float side = (i % 2 == 0) ? 1.0 : -1.0;
        float2 o = mix(a, b, t);
        float reach = (0.36 - 0.026 * float(i)) * (0.85 + 0.3 * h01u(sd + uint(i) * 3u));
        float2 e = o + float2(side * reach * 0.82, reach * 0.58);
        float al2 = 0.0, tp2 = 0.0;
        float v2 = cfComb(p, o, e, 0.062, 0.0032, ang, 0.008, sd + uint(i) * 31u, al2, tp2);
        if (v2 > best) { best = v2; along = al2; tipness = tp2; fresh = smoothstep(0.75, 0.97, al2) * step(0.35, h01u(sd + uint(i) * 5u + 1u)); }
    }
    float2 ab = b - a; float h = clamp(dot(p - a, ab) / dot(ab, ab), 0.0, 1.0);
    float tw = length(p - (a + ab * h));
    if (tw < 0.009 && best < 0.3) { s.alpha = 1.0; s.albedo = float3(0.16, 0.12, 0.06); s.height = 0.4; s.rough = 0.8; }
    if (best > 0.0) {
        s.alpha = 1.0;
        float3 c = mix(P.colorA.rgb, P.colorB.rgb, h01u(sd + uint(along * 400.0)));
        c = mix(c, P.colorC.rgb, fresh * P.f.y);
        // Midrib groove: lighter edges, darker center line on the upper face.
        c *= 0.78 + 0.3 * best + 0.12 * tipness;
        s.albedo = c; s.height = 0.5 + 0.45 * best; s.rough = 0.38 + 0.12 * tipness;
        s.ao = 0.65 + 0.35 * tipness;
    }
    return s;
}

// Cypress scale foliage: dense spray of beaded cord-like branchlets.
float cfCord(float2 p, float2 a, float2 b, float r0, float r1, float bead, thread float &tAlong) {
    float2 ab = b - a; float h = clamp(dot(p - a, ab) / dot(ab, ab), 0.0, 1.0);
    float d = length(p - (a + ab * h));
    float r = mix(r0, r1, h) * (0.82 + 0.18 * abs(sin(h * length(ab) * bead)));
    tAlong = h;
    return d < r ? sqrt(1.0 - (d / r) * (d / r)) : 0.0;
}
S leafCypress(float2 uv, constant RFParams &P) {
    S s = defaults(); s.alpha = 0.0; s.rough = 0.6;
    float g = P.f.z > 0.5 ? P.f.z : 2.0;
    float2 cuv = uv * g; int2 cell = int2(floor(cuv)); float2 p = cuv - floor(cuv);
    uint sd = P.seed + uint(cell.x * 7 + cell.y * 13);
    s.albedo = mix(P.colorA.rgb, P.colorB.rgb, 0.4);
    float best = 0.0, along = 0.0, lvl = 0.0, tipT = 0.0;
    float bend = (h01u(sd) - 0.5) * 0.15;
    float2 a = float2(0.5, 0.0), b = float2(0.5 + bend, 0.92);
    float t0 = 0.0;
    float v = cfCord(p, a, b, 0.03, 0.016, 140.0, t0);
    if (v > best) { best = v; along = t0; lvl = 0.0; tipT = t0; }
    for (int i = 0; i < 9; i++) {
        uint li = sd + 20u + uint(i) * 13u;
        float t = 0.08 + 0.1 * float(i);
        float side = (i % 2 == 0) ? 1.0 : -1.0;
        float2 o = mix(a, b, t);
        float reach = (0.44 - 0.035 * float(i)) * (0.8 + 0.35 * h01u(li));
        float ang = side * (0.5 + 0.35 * h01u(li + 1u));
        float2 d1 = float2(sin(ang), cos(ang));
        float2 e = o + d1 * reach;
        // Quick reject: skip the whole lateral when the texel is far from it.
        float2 oe = e - o; float hq = clamp(dot(p - o, oe) / dot(oe, oe), 0.0, 1.0);
        if (length(p - (o + oe * hq)) > reach * 0.55 + 0.04) continue;
        float t1 = 0.0;
        float v1 = cfCord(p, o, e, 0.022, 0.012, 160.0, t1);
        if (v1 > best) { best = v1; along = t; lvl = 1.0; tipT = t1; }
        for (int j = 0; j < 6; j++) {
            uint lj = li + 100u + uint(j) * 7u;
            float tj = 0.12 + 0.14 * float(j) + 0.06 * h01u(lj);
            float2 oj = mix(o, e, tj);
            float side2 = (j % 2 == 0) ? 1.0 : -1.0;
            float ang2 = ang + side2 * (0.55 + 0.3 * h01u(lj + 1u));
            float r2 = reach * (0.46 - 0.05 * float(j)) * (0.8 + 0.4 * h01u(lj + 2u));
            float2 dj = float2(sin(ang2), cos(ang2));
            float2 ej = oj + dj * r2;
            float t2 = 0.0;
            float v2 = cfCord(p, oj, ej, 0.017, 0.009, 180.0, t2);
            if (v2 > best) { best = v2; along = t + float(j) * 0.01; lvl = 2.0; tipT = t2; }
            for (int k = 0; k < 2; k++) {
                uint lk = lj + 50u + uint(k) * 3u;
                float2 ok = mix(oj, ej, 0.35 + 0.3 * float(k));
                float ang3 = ang2 + (k == 0 ? 1.0 : -1.0) * (0.6 + 0.3 * h01u(lk));
                float2 ek = ok + float2(sin(ang3), cos(ang3)) * r2 * (0.35 + 0.2 * h01u(lk + 1u));
                float t3 = 0.0;
                float v3 = cfCord(p, ok, ek, 0.013, 0.007, 200.0, t3);
                if (v3 > best) { best = v3; along = t + float(j) * 0.01 + 0.005; lvl = 3.0; tipT = t3; }
            }
        }
    }
    if (best > 0.0) {
        s.alpha = 1.0;
        float var = h01u(sd + uint(along * 50.0) + uint(lvl) * 977u);
        float3 c = mix(P.colorA.rgb, P.colorB.rgb, var);
        float tipLight = smoothstep(0.55, 1.0, tipT) * (lvl > 1.5 ? 1.0 : 0.3);
        c = mix(c, P.colorC.rgb, tipLight * P.f.x);
        // Scale texture: tiny overlapping scales as a fine bead pattern.
        float sc = fbm(p, int2(64, 64), 2, sd + 7u);
        c *= 0.72 + 0.3 * best + 0.25 * sc;
        s.albedo = c; s.height = 0.3 + 0.5 * best + 0.15 * (3.0 - lvl) / 3.0 + 0.06 * sc;
        s.rough = 0.55 + 0.1 * var;
        s.ao = 0.55 + 0.45 * best;
    }
    return s;
}

// Palm trunk: leaf-scar rings along v, shallow vertical fissures. f.x ring strength, f.y rings per tile.
// With f.x = 0 it reads as fibrous husk (coconut).
S barkPalm(float2 uv, constant RFParams &P) {
    S s = defaults(); uint sd = P.seed;
    float rings = P.f.y > 0.5 ? P.f.y : 6.0;
    float fine = fbm(uv, int2(32, 32), 3, sd + 1u);
    float big = fbm(uv, int2(3, 2), 4, sd + 2u);
    float fiss = ridged(uv, int2(18, 2), 3, sd + 3u);
    float fib = fbm(uv, int2(96, 6), 3, sd + 4u);
    float wav = gnoise(uv * float2(5.0, rings), int2(5, int(rings)), sd + 5u) * 0.25;
    float rp = fract(uv.y * rings + wav);
    // Scar: a sharp lip (ridge) followed by a recessed band, then the smooth internode.
    float lip = smoothstep(0.0, 0.05, rp) * (1.0 - smoothstep(0.05, 0.16, rp));
    float band = (1.0 - smoothstep(0.12, 0.3, rp)) * smoothstep(0.04, 0.12, rp);
    float ring = P.f.x;
    float crack = smoothstep(0.72, 0.95, fiss);
    s.height = 0.55 + ring * (0.25 * lip - 0.2 * band) - 0.25 * crack + 0.06 * fine + 0.05 * fib;
    float3 c = mix(P.colorA.rgb, P.colorC.rgb, smoothstep(-0.1, 0.35, big + 0.3 * fine));
    c *= 0.88 + 0.2 * fib + 0.1 * fine;
    c = mix(c, P.colorB.rgb, ring * (band * 0.65 + 0.2 * lip * (1.0 - band)));
    c = mix(c, P.colorB.rgb * 0.8, crack * 0.7);
    s.albedo = c;
    s.rough = 0.88 - 0.25 * (1.0 - ring) + 0.05 * crack;
    s.ao = mix(1.0, 0.45, max(ring * band * 0.8, crack));
    return s;
}

// Pinnate palm frond. Cells across u (f.z per row), one frond per cell, base at v = 0, tip at v = 1.
// Rachis on the cell center line, leaflets angled forward. Frond width = f.w * length (default 0.36).
S leafPalm(float2 uv, constant RFParams &P) {
    S s = defaults(); s.alpha = 0.0; s.rough = 0.45;
    float g = P.f.z > 0.5 ? P.f.z : 2.0;
    float cx = uv.x * g; int cell = int(floor(cx));
    float aspect = P.f.w > 0.0 ? P.f.w : 0.36;
    float2 q = float2((cx - floor(cx) - 0.5) * aspect, uv.y);   // in frond lengths
    uint sd = P.seed + uint(cell) * 7919u;
    s.albedo = mix(P.colorA.rgb, P.colorB.rgb, 0.5);
    float t = q.y;
    float ax = abs(q.x);
    float side = q.x >= 0.0 ? 1.0 : -1.0;
    // Rachis.
    float rw = 0.0065 * (1.0 - 0.75 * t) + 0.0012;
    if (ax < rw && t > 0.0 && t < 0.985) {
        float r = ax / rw;
        s.alpha = 1.0;
        s.albedo = mix(P.colorC.rgb * float3(1.0, 1.05, 0.7), P.colorB.rgb, 0.35) * (0.85 + 0.25 * sqrt(1.0 - r * r));
        s.height = 0.75 + 0.25 * sqrt(1.0 - r * r); s.rough = 0.5; s.ao = 1.0;
        return s;
    }
    float ang = 0.95 + 0.1 * P.f.x;                 // leaflet angle from the rachis (radians)
    float spacing = 0.015;
    float y0 = t - ax / tan(ang);                     // where a straight leaflet through here leaves the rachis
    float kc = floor(y0 / spacing);
    float best = -1.0;
    for (int dk = -2; dk <= 2; dk++) {
        float k = kc + float(dk);
        float tb = k * spacing;
        if (tb < 0.015 || tb > 0.975) continue;
        uint li = sd + uint(int(k) * 2 + (side > 0.0 ? 1 : 0)) * 13u;
        if (h01u(li) < 0.035) continue;               // missing / torn leaflet
        float jit = (h01u(li + 1u) - 0.5) * 0.12;
        float a2 = ang + jit;
        float2 dir = float2(sin(a2) * side, cos(a2));
        float2 o = float2(side * rw * 0.8, tb + (h01u(li + 2u) - 0.5) * spacing * 0.5);
        // Leaflet length: short at base and tip, longest past the middle.
        float Lmax = aspect * 0.5 / sin(a2) * 0.98;
        float L = Lmax * (0.32 + 0.68 * pow(sin(3.14159 * clamp(0.12 + 0.88 * tb, 0.0, 1.0)), 0.7)) * (0.88 + 0.12 * h01u(li + 3u));
        if (tb > 0.8) L *= mix(1.0, 0.45, (tb - 0.8) / 0.2);
        float2 d = q - o;
        float x = dot(d, dir);
        if (x < 0.0 || x > L) continue;
        float u = x / L;
        float2 nr = float2(dir.y, -dir.x) * side;
        float droop = (0.05 + 0.04 * h01u(li + 4u)) * L;   // leaflets sweep toward the tip
        float y = dot(d, nr) * side - droop * u * u;
        float wmax = 0.0072 * (0.85 + 0.3 * h01u(li + 5u));
        float w = wmax * pow(sin(3.14159 * clamp(pow(u, 0.55), 0.0, 1.0)), 0.6) + 0.0012 * (1.0 - u);
        // Split tips.
        bool split = h01u(li + 6u) < 0.25 && u > 0.82 && abs(y) < w * 0.25;
        if (abs(y) > w || split) continue;
        float depth = h01u(li + 7u);
        if (depth < best) continue;
        best = depth;
        float yn = y / max(w, 1e-4);
        float var = h01u(li + 8u);
        float3 c = mix(P.colorA.rgb, P.colorB.rgb, var * 0.7 + 0.3 * u);
        // Dry brown tips on some leaflets, more on old fronds (f.y).
        float dry = smoothstep(1.0 - (0.08 + 0.3 * h01u(li + 9u)) , 1.0, u) * step(1.0 - (0.35 + P.f.y), h01u(li + 10u));
        c = mix(c, P.colorC.rgb * (0.8 + 0.3 * var), dry);
        float mid = 1.0 - smoothstep(0.0, 0.18, abs(yn));
        c = mix(c, c * 1.25 + float3(0.02, 0.025, 0.0), mid * 0.6);
        c *= 0.85 + 0.15 * (1.0 - yn * yn) + 0.08 * fbm(q * float2(1.0 / aspect, 1.0), int2(8, 64), 2, li);
        s.albedo = c; s.alpha = 1.0;
        s.height = 0.4 + 0.3 * (1.0 - yn * yn) + 0.2 * mid;
        s.rough = 0.4 + 0.2 * dry + 0.06 * var;
        s.ao = 0.7 + 0.3 * u;
    }
    return s;
}

// Ribbed cactus skin. One rib per repeat across u with the crest at u = 0; v in tiles.
// f.x spine length, f.y areole rows per tile, f.z areole wool, f.w rib width / tile height.
S cactusRibs(float2 uv, constant RFParams &P) {
    S s = defaults(); uint sd = P.seed;
    float rows = P.f.y > 0.5 ? P.f.y : 10.0;
    float ws = P.f.w > 0.0 ? P.f.w : 0.4;
    float du = uv.x - floor(uv.x + 0.5);              // -0.5..0.5, crest at 0
    float fine = fbm(uv, int2(24, 24), 3, sd + 1u);
    float stria = fbm(uv, int2(64, 4), 2, sd + 2u);
    float big = fbm(uv, int2(2, 2), 4, sd + 3u);
    float groove = smoothstep(0.32, 0.5, abs(du));
    float3 c = mix(P.colorA.rgb, P.colorB.rgb, 0.35 + 0.4 * big + 0.25 * groove);
    c *= 0.9 + 0.12 * stria + 0.08 * fine;
    // Faint horizontal growth bands.
    c *= 0.96 + 0.06 * sin(uv.y * 6.2831853 * 3.0 + big * 4.0);
    float h = 0.6 - 0.25 * groove + 0.03 * stria;
    float rough = 0.62 + 0.1 * fine;
    float ao = 1.0 - 0.45 * groove;
    // Areoles along the crest, with radiating spines.
    float vy = uv.y * rows;
    float k0 = floor(vy);
    float spineBest = 0.0; float spineT = 0.0; float wool = 0.0;
    for (int dk = -1; dk <= 1; dk++) {
        float k = k0 + float(dk);
        int ki = int(k) - int(floor(k / rows) * rows);
        uint ai = sd + 300u + uint(ki) * 17u + uint(floor(uv.x + 0.5) + 64.0) * 4099u;
        float2 a = float2(0.0, (k + 0.5 + (h01u(ai) - 0.5) * 0.3) / rows);
        float2 d = float2(du * ws, uv.y - a.y);
        float rA = 0.014 / ws * 0.4 + 0.006;
        float dl = length(d);
        wool = max(wool, 1.0 - smoothstep(rA * 0.6, rA, dl));
        int nsp = 7;
        for (int j = 0; j < 7; j++) {
            if (j >= nsp) break;
            uint sj = ai + 10u + uint(j) * 5u;
            float an = (float(j) / float(nsp)) * 6.2831853 + h01u(sj) * 0.6;
            bool central = j == 0;
            if (central) an = 3.14159 + (h01u(sj) - 0.5) * 0.6;     // central spine points down
            float2 dir = float2(sin(an), cos(an));
            float L = P.f.x * (central ? 0.11 : 0.05 + 0.04 * h01u(sj + 1u));
            float tt = 0.0;
            float v = cfNeedle(d, float2(0.0), dir, L, central ? 0.0035 : 0.0024, (h01u(sj + 2u) - 0.5) * 0.3, 0.0, tt);
            if (v > spineBest) { spineBest = v; spineT = tt; }
        }
    }
    float wl = wool * P.f.z;
    c = mix(c, float3(0.42, 0.38, 0.3), wl);
    h = mix(h, 0.75, wl); rough = mix(rough, 0.95, wl);
    if (spineBest > 0.0) {
        float3 sc = P.colorC.rgb * (0.75 + 0.35 * spineBest) * mix(0.75, 1.15, spineT);
        c = mix(c, sc, smoothstep(0.0, 0.3, spineBest));
        h = max(h, 0.75 + 0.25 * spineBest);
        rough = mix(rough, 0.5, spineBest);
        ao = 1.0;
    }
    s.albedo = c; s.height = h; s.rough = rough; s.ao = ao;
    return s;
}

// Agave leaf: glaucous blue-green wax bloom, fine longitudinal striation, bud imprints (ghost teeth bands).
S leafAgave(float2 uv, constant RFParams &P) {
    S s = defaults(); uint sd = P.seed;
    float fine = fbm(uv, int2(16, 16), 4, sd + 1u);
    float stria = fbm(uv, int2(80, 3), 3, sd + 2u);
    float bloom = fbm(uv, int2(3, 2), 4, sd + 3u);
    float bands = P.f.y > 0.5 ? P.f.y : 4.0;
    float wav = gnoise(uv * float2(2.0, bands), int2(2, int(bands)), sd + 4u) * 0.35;
    float bp = fract(uv.y * bands + wav);
    // Imprint: a zigzag line of tooth shadows pressed into the wax.
    float zig = abs(fract(uv.x * 14.0) - 0.5) * 0.08;
    float imprint = (1.0 - smoothstep(0.0, 0.035, abs(bp - 0.5 - zig))) * P.f.x;
    float shadow = smoothstep(0.5, 0.62, bp) * (1.0 - smoothstep(0.62, 0.9, bp)) * P.f.x * 0.5;
    float3 c = mix(P.colorA.rgb, P.colorC.rgb, smoothstep(-0.2, 0.35, bloom + 0.25 * fine));
    c *= 0.92 + 0.1 * stria + 0.06 * fine;
    c = mix(c, P.colorB.rgb, max(imprint * 0.55, shadow * 0.35));
    s.albedo = c;
    s.height = 0.55 + 0.05 * stria + 0.04 * fine - 0.12 * imprint;
    s.rough = 0.55 + 0.12 * bloom - 0.05 * imprint;
    s.ao = 1.0 - 0.2 * imprint;
    return s;
}
"""#
