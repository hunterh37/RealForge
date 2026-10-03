// Ground-cover programs: grassBlade, grassCard, flowers, fernFrond, leafLitter, moss, fungus, plantStem.
// Atlas programs draw with v up the card (root at v = 0).

let metalPlant = #"""
// ---------------------------------------------------------------- plants and ground cover
// Per-blade colour: green base to lighter tip, optional yellow tip, some blades dead (straw).
float3 plBladeColor(uint bi, float t, constant RFParams &P, thread float &dryOut) {
    float h1 = h01u(bi), h2 = h01u(bi + 1u), h3 = h01u(bi + 2u), h4 = h01u(bi + 3u);
    float3 g = mix(P.colorA.rgb, P.colorB.rgb, 0.15 + 0.7 * h2);
    g = mix(g, P.colorA.rgb, 0.35 * (1.0 - smoothstep(0.0, 0.5, t)));          // darker low in the tuft
    g = mix(g * float3(1.25, 1.15, 0.75), g, smoothstep(0.0, 0.12, t));      // pale sheath at the root
    float tipAmt = P.f.y * smoothstep(0.25, 1.0, h3);
    float3 tipCol = mix(P.colorB.rgb, P.colorC.rgb, 0.7) * 1.15;
    g = mix(g, tipCol, smoothstep(1.0 - 0.55 * tipAmt, 1.0, t) * step(0.02, tipAmt));
    float dead = step(h1, P.f.x);
    float3 straw = P.colorC.rgb * (0.7 + 0.45 * h4);
    straw = mix(straw * 0.75, straw, smoothstep(0.0, 0.4, t));
    dryOut = dead;
    return mix(g, straw, dead);
}

// Blade strip atlas: P.f.z columns, each one blade variant. u across the blade, v root to tip.
// f.x dead fraction, f.y yellow tips, f.w > 0.5 mown (cut tips).
S grassBlade(float2 uv, constant RFParams &P) {
    S s = defaults();
    float cols = P.f.z > 0.5 ? P.f.z : 8.0;
    float cx = uv.x * cols; float ci = floor(cx); float x = cx - ci; float y = uv.y;
    uint bi = P.seed + uint(ci) * 37u + 5u;
    float dry = 0.0;
    float3 c = plBladeColor(bi, y, P, dry);
    float ax = abs(x - 0.5) * 2.0;
    // Long streaks and parallel veins.
    float streak = fbm(float2(uv.x, y), int2(int(cols) * 10, 3), 3, P.seed + 11u);
    float vein = 0.5 + 0.5 * cos(x * 6.2831853 * 6.0);
    float mid = 1.0 - smoothstep(0.0, 0.12, ax);
    c *= 0.9 + 0.35 * streak + 0.06 * vein;
    c = mix(c, c * 1.18 + float3(0.01, 0.015, 0.0), mid * 0.6);
    c *= 1.0 - 0.18 * smoothstep(0.75, 1.0, ax);
    // Rust spots and tip die-back on some green blades.
    float4 w = worley(float2(uv.x, y), int2(int(cols) * 3, 24), P.seed + 21u, 0.9);
    float spot = (1.0 - smoothstep(0.05, 0.12, w.x)) * step(0.82, w.z) * (1.0 - dry);
    c = mix(c, P.colorC.rgb * 0.55, spot * 0.7);
    if (P.f.w > 0.5) {
        float cut = smoothstep(0.9, 0.98, y + 0.03 * h01u(bi + 9u));
        c = mix(c, P.colorC.rgb * 0.9, cut * 0.8);
    }
    s.albedo = c;
    s.alpha = 1.0;
    s.height = 0.5 + 0.18 * (1.0 - ax * ax) - 0.14 * mid + 0.05 * vein + 0.05 * streak;
    s.rough = mix(0.42 + 0.12 * h01u(bi + 7u), 0.78, dry);
    s.ao = 0.75 + 0.25 * smoothstep(0.0, 0.35, y);
    return s;
}

// Distance cards, 2x2 atlas. (0,0) blade clump, (1,0) blade clump with seed stalks,
// (0,1) single seed-head panicle, (1,1) top-down thatch. f.z > 0.5: the whole texture is tiling thatch.
float plSeg(float2 p, float2 a, float2 b, thread float &t) {
    float2 ab = b - a; t = clamp(dot(p - a, ab) / max(dot(ab, ab), 1e-6), 0.0, 1.0);
    return length(p - (a + ab * t));
}
float plSpikelet(float2 p, float2 c0, float2 dir, float L, float W, uint id, constant RFParams &P,
                 thread float &best, thread float3 &col, thread float &hgt) {
    float2 q = p - c0;
    float lx = dot(q, dir), ly = dot(q, float2(dir.y, -dir.x));
    // Pointed ellipse (lemma shape): narrower toward the tip.
    float w = W * (1.0 - 0.45 * smoothstep(-0.2, 1.0, lx / L));
    float e = (lx * lx) / (L * L) + (ly * ly) / (w * w);
    float hk = 0.3 + h01u(id);
    if (e >= 1.0 || hk <= best) return 0.0;
    best = hk;
    float v = h01u(id + 5u);
    col = mix(P.colorA.rgb, P.colorB.rgb, v) * (0.75 + 0.45 * (1.0 - e));
    col = mix(col, P.colorC.rgb, step(0.8, h01u(id + 7u)) * step(0.3, lx / L) * 0.85);   // anthers / purple tint
    hgt = 0.6 + 0.3 * (1.0 - e);
    return 1.0;
}
// Loose grass panicle: axis, 6-8 nodes of 1-3 thin curved branches held close to the axis,
// spikelets jittered along each branch, a cluster at the axis tip.
float plPanicle(float2 p, uint sd, constant RFParams &P, thread float3 &col, thread float &hgt, float2 base, float top, float scale) {
    float hit = 0.0; float best = -1.0;
    float t; float d = plSeg(p, base, float2(base.x, top), t);
    if (d < 0.0045 * scale * (1.2 - t * 0.6)) { hit = 1.0; col = mix(P.colorA.rgb, P.colorB.rgb, 0.4) * 0.8; hgt = 0.5; best = 0.0; }
    float start = mix(base.y, top, 0.4 + 0.15 * h01u(sd));
    int nodes = 6 + int(h01u(sd + 1u) * 3.0);
    for (int i = 0; i < 8; i++) {
        if (i >= nodes) break;
        uint ni = sd + uint(i) * 13u;
        float f = (float(i) + 0.3 * h01u(ni + 2u)) / float(nodes);
        float ty = mix(start, top - 0.06 * scale, f);
        float reach = (0.30 - 0.22 * f) * scale * (0.6 + 0.6 * h01u(ni));
        int nb = 1 + int(h01u(ni + 3u) * 2.6);
        for (int j = 0; j < 3; j++) {
            if (j >= nb) break;
            uint bj = ni + uint(j) * 101u;
            float sgn = (h01u(bj + 4u) > 0.5) ? 1.0 : -1.0;
            float ang = sgn * (0.12 + 0.45 * h01u(bj + 5u)) * (1.0 - 0.4 * f);
            float2 a = float2(base.x, ty);
            float2 dir = float2(sin(ang), cos(ang));
            float2 mid = a + dir * reach * 0.5;
            float2 dir2 = normalize(dir + float2(sgn * 0.12, -0.1 * h01u(bj + 6u)));
            float2 b = mid + dir2 * reach * 0.5;
            float tb; float db = min(plSeg(p, a, mid, tb), plSeg(p, mid, b, tb));
            if (db < 0.0022 * scale && 0.1 > best) { hit = 1.0; best = 0.1; col = P.colorA.rgb * 0.85; hgt = 0.45; }
            for (int k = 0; k < 5; k++) {
                uint sk = bj + uint(k) * 17u + 30u;
                float tk = 0.3 + 0.7 * (float(k) + 0.6 * h01u(sk)) / 5.0;
                float2 c0 = tk < 0.5 ? mix(a, mid, tk * 2.0) : mix(mid, b, tk * 2.0 - 1.0);
                float2 dk = normalize(dir2 + float2(dir2.y, -dir2.x) * (h01u(sk + 1u) - 0.5) * 0.9);
                c0 += float2(dir2.y, -dir2.x) * (h01u(sk + 2u) - 0.5) * 0.02 * scale + dk * 0.018 * scale;
                float L = (0.022 + 0.014 * h01u(sk + 3u)) * scale, W = 0.009 * scale;
                hit = max(hit, plSpikelet(p, c0, dk, L, W, sk + 4u, P, best, col, hgt));
            }
        }
    }
    for (int k = 0; k < 4; k++) {
        uint sk = sd + 900u + uint(k) * 7u;
        float2 dk = normalize(float2((h01u(sk) - 0.5) * 0.6, 1.0));
        float2 c0 = float2(base.x, top - (0.015 + 0.03 * float(k)) * scale) + dk * 0.015 * scale;
        hit = max(hit, plSpikelet(p, c0, dk, 0.028 * scale, 0.009 * scale, sk + 1u, P, best, col, hgt));
    }
    return hit;
}
// Top-down mown thatch: three layers of short strokes over dark gaps. Periodic over p in [0, 1).
void plThatch(float2 p, uint sd, constant RFParams &P, thread S &s) {
    float n = fbm(p, int2(4, 4), 4, sd + 3u);
    s.albedo = P.colorA.rgb * (0.35 + 0.2 * n); s.alpha = 1.0; s.height = 0.2; s.ao = 0.5; s.rough = 0.8;
    for (int layer = 0; layer < 3; layer++) {
        float cid = 0.0, cid2 = 0.0;
        int fr = 22 + layer * 9;
        float2 off = cellLocal(p, int2(fr, fr), sd + 30u + uint(layer) * 17u, cid, cid2);
        float2 q = rot2(off, cid * 6.2831853);
        float L = 0.75, W = 0.11 * (0.6 + 0.6 * cid2);
        float lx = q.x / L;
        if (abs(lx) < 1.0 && abs(q.y) < W * (1.0 - lx * lx)) {
            float dry = 0.0;
            float3 c = plBladeColor(uint(cid * 1e6) + sd, 0.6 + 0.4 * cid2, P, dry);
            s.albedo = c * (0.8 + 0.25 * n + 0.15 * float(layer)); s.height = 0.4 + 0.2 * float(layer); s.ao = 0.7 + 0.15 * float(layer);
            s.rough = 0.55 + 0.2 * dry;
        }
    }
}
S grassCard(float2 uv, constant RFParams &P) {
    S s = defaults(); s.alpha = 0.0; s.rough = 0.6;
    s.albedo = mix(P.colorA.rgb, P.colorB.rgb, 0.4);
    if (P.f.z > 0.5) { plThatch(uv, P.seed, P, s); return s; }       // opaque tiling thatch mode
    float2 cuv = uv * 2.0; int2 cell = int2(floor(cuv)); float2 p = cuv - floor(cuv);
    uint sd = P.seed + uint(cell.x * 7 + cell.y * 13);
    if (cell.y == 0) {
        float best = -1.0;
        for (int i = 0; i < 44; i++) {
            uint bi = sd + uint(i) * 23u;
            float x0 = 0.2 + 0.6 * h01u(bi);
            float hh = 0.35 + 0.6 * h01u(bi + 1u);
            float lean = (x0 - 0.5) * 0.9 + (h01u(bi + 2u) - 0.5) * 0.5;
            float w0 = 0.007 + 0.009 * h01u(bi + 3u);
            if (p.y > hh) continue;
            float t = p.y / hh;
            float cx = x0 + lean * t * t * hh;
            float hw = w0 * (1.0 - pow(t, 1.4)) + 0.0015;
            float dx = abs(p.x - cx);
            if (dx > hw) continue;
            float depth = h01u(bi + 4u);
            if (depth < best) continue;
            best = depth;
            float dry = 0.0;
            float3 c = plBladeColor(bi + 100u, t, P, dry);
            float rib = 1.0 - dx / max(hw, 1e-4);
            s.albedo = c * (0.8 + 0.3 * rib) * (0.75 + 0.25 * depth); s.alpha = 1.0;
            s.height = 0.4 + 0.5 * rib; s.rough = 0.5 + 0.25 * dry;
            s.ao = mix(0.45, 1.0, smoothstep(0.0, 0.6, t));
        }
        if (cell.x == 1) {
            for (int j = 0; j < 4; j++) {
                uint ji = sd + 500u + uint(j) * 41u;
                float bx = 0.3 + 0.4 * h01u(ji);
                float top = 0.82 + 0.15 * h01u(ji + 1u);
                float3 col = s.albedo; float hg = 0.0;
                if (plPanicle(p, ji, P, col, hg, float2(bx, 0.0), top, 0.45) > 0.5) {
                    // Seed heads read tan against the green.
                    s.albedo = mix(col, P.colorC.rgb * 1.1, 0.6); s.alpha = 1.0; s.height = hg; s.rough = 0.7; s.ao = 1.0;
                }
            }
        }
    } else if (cell.x == 0) {
        float3 col = s.albedo; float hg = 0.0;
        s.albedo = mix(P.colorB.rgb, P.colorC.rgb, 0.5);
        if (plPanicle(p, sd, P, col, hg, float2(0.5, 0.0), 0.97, 1.0) > 0.5) {
            s.albedo = col; s.alpha = 1.0; s.height = hg; s.rough = 0.65; s.ao = 1.0;
        }
    } else {
        plThatch(p, sd, P, s);
    }
    return s;
}

// Wildflower atlas, 4x4. 0 daisy, 1 poppy, 2 cornflower, 3 buttercup, 4 dandelion, 5 dandelion clock,
// 6 white clover head, 7 clover leaf, 8 dandelion leaf, 9 ivy leaf, 10 narrow stem leaf, 11 red clover head.
// Heads are top views centred in the cell; leaves run up the cell from the bottom centre.
float3 plLeafColor(float var, float2 p, uint sd, constant RFParams &P) {
    float3 c = mix(P.colorA.rgb, P.colorB.rgb, var);
    return c * (0.85 + 0.3 * fbm(p, int2(6, 6), 3, sd));
}
S flowers(float2 uv, constant RFParams &P) {
    S s = defaults(); s.alpha = 0.0; s.rough = 0.55;
    float g = P.f.z > 0.5 ? P.f.z : 4.0;
    float2 cuv = uv * g; int2 cell = int2(floor(cuv)); float2 p = cuv - floor(cuv);
    int idx = cell.y * int(g) + cell.x;
    uint sd = P.seed + uint(idx) * 31u;
    float2 d = p - 0.5; float r = length(d); float ang = atan2(d.y, d.x);
    s.albedo = P.colorB.rgb;
    float fine = fbm(p, int2(16, 16), 3, sd + 1u);
    if (idx == 0) {                                   // oxeye daisy
        float N = 22.0;
        float k = floor(ang / 6.2831853 * N + 0.5);
        float a0 = k / N * 6.2831853;
        float L = 0.40 + 0.06 * h01u(sd + uint(k + 40.0));
        float dl = ang - a0; float across = r * sin(dl);
        float tt = (r - 0.1) / (L - 0.1);
        float hw = 0.042 * pow(max(sin(3.14159 * clamp(tt, 0.0, 1.0) * 0.92 + 0.15), 0.0), 0.6);
        if (r < 0.115) {
            float dots = 0.5 + 0.5 * sin(r * 260.0) * sin(ang * 30.0);
            s.albedo = mix(float3(0.62, 0.34, 0.01), float3(0.85, 0.55, 0.03), dots) * (1.0 - 0.3 * smoothstep(0.08, 0.115, r));
            s.alpha = 1.0; s.height = 0.8 - r * 2.0 + 0.1 * dots; s.rough = 0.7;
        } else if (tt > 0.0 && tt < 1.0 && abs(across) < hw) {
            float e = abs(across) / hw;
            s.albedo = float3(0.80, 0.80, 0.76) * (0.88 + 0.12 * (1.0 - e)) * (0.82 + 0.18 * smoothstep(0.0, 0.25, tt)) * (0.95 + 0.1 * fine);
            s.alpha = 1.0; s.height = 0.5 + 0.2 * (1.0 - e) - 0.05 * cos(across * 400.0); s.rough = 0.5;
        }
    } else if (idx == 1) {                            // corn poppy
        float best = -1.0;
        for (int i = 0; i < 4; i++) {
            float pa = float(i) * 1.5708 + 0.4 + 0.2 * h01u(sd + uint(i));
            float2 c0 = float2(cos(pa), sin(pa)) * 0.17;
            float2 q = rot2(d - c0, -pa);
            float e = length(q / float2(0.29, 0.30));
            float z = (i % 2 == 0) ? 0.4 : 0.6;
            if (e < 1.0 && r < 0.47 && z > best) {
                best = z;
                float crinkle = fbm(float2(ang / 6.2831853 + 0.5, r), int2(24, 3), 3, sd + 5u);
                s.albedo = float3(0.70, 0.022, 0.012) * (0.75 + 0.35 * crinkle + 0.15 * e);
                if (r < 0.13) s.albedo = mix(float3(0.015, 0.012, 0.014), s.albedo, smoothstep(0.08, 0.13, r));
                s.alpha = 1.0; s.height = 0.4 + z * 0.3 + 0.1 * crinkle - 0.2 * (1.0 - e) * (i % 2 == 0 ? 1.0 : 0.0); s.rough = 0.45;
            }
        }
        if (r < 0.055) { s.albedo = float3(0.12, 0.16, 0.08) * (0.8 + 0.4 * (0.5 + 0.5 * cos(ang * 9.0))); s.alpha = 1.0; s.height = 0.95; s.rough = 0.6; }
        else if (r < 0.1 && h01u(uint(ang * 40.0) + sd) > 0.4) { s.albedo = float3(0.02, 0.018, 0.025); s.alpha = 1.0; s.height = 0.85; }
    } else if (idx == 2) {                            // cornflower
        float N = 8.0;
        float k = floor(ang / 6.2831853 * N + 0.5);
        float dl = ang - k / N * 6.2831853;
        float edge = 0.41 + 0.05 * abs(sin(ang * 40.0)) + 0.02 * h01u(sd + uint(k + 9.0));
        float wedge = abs(dl) < (0.18 + 0.32 * smoothstep(0.1, 0.42, r)) ? 1.0 : 0.0;
        if (r < 0.14) {
            s.albedo = float3(0.10, 0.02, 0.20) * (0.7 + 0.5 * (0.5 + 0.5 * sin(ang * 23.0) * sin(r * 300.0)));
            s.alpha = 1.0; s.height = 0.75; s.rough = 0.6;
        } else if (r < edge && wedge > 0.5) {
            float ribs = 0.5 + 0.5 * cos(dl * 60.0);
            s.albedo = float3(0.035, 0.10, 0.62) * (0.75 + 0.3 * ribs) * (0.8 + 0.25 * smoothstep(0.14, 0.4, r));
            s.alpha = 1.0; s.height = 0.5 + 0.2 * ribs; s.rough = 0.5;
        }
    } else if (idx == 3) {                            // buttercup
        float N = 5.0;
        float k = floor(ang / 6.2831853 * N + 0.5);
        float dl = ang - k / N * 6.2831853;
        float pr = 0.42 * pow(max(cos(dl * 2.2), 0.0), 0.35);
        if (r < 0.1) {
            float dots = step(0.55, h01u(uint(ang * 20.0) + uint(r * 80.0) * 7u + sd));
            s.albedo = mix(float3(0.45, 0.42, 0.02), float3(0.75, 0.50, 0.0), dots); s.alpha = 1.0; s.height = 0.8; s.rough = 0.6;
        } else if (r < pr) {
            s.albedo = float3(0.86, 0.58, 0.0) * (0.85 + 0.2 * (r / pr)); s.alpha = 1.0;
            s.height = 0.5 + 0.2 * (1.0 - r / pr); s.rough = 0.18;
        }
    } else if (idx == 4) {                            // dandelion flower
        float edge = 0.40 + 0.05 * abs(sin(ang * 34.0)) + 0.02 * fine;
        if (r < edge) {
            float rays = 0.5 + 0.5 * cos(ang * 68.0 + r * 30.0);
            float3 c = mix(float3(0.85, 0.36, 0.0), float3(0.92, 0.62, 0.02), smoothstep(0.0, 0.35, r));
            s.albedo = c * (0.8 + 0.25 * rays); s.alpha = 1.0;
            s.height = 0.7 - r * 0.6 + 0.1 * rays; s.rough = 0.55;
        }
    } else if (idx == 5) {                            // dandelion seed clock
        float rays = abs(fract(ang / 6.2831853 * 90.0 + h01u(uint(r * 30.0) + sd) * 0.3) - 0.5);
        float pappus = smoothstep(0.32, 0.46, r) * (1.0 - smoothstep(0.46, 0.48, r));
        float puffN = fbm(p, int2(24, 24), 3, sd + 8u);
        float fill = fbm(p, int2(48, 48), 2, sd + 9u);
        bool hit = (r < 0.47 && rays < 0.07 && r > 0.06) || (pappus > 0.3 && puffN > -0.15) || (r < 0.44 && fill > 0.12 - 0.25 * r);
        if (r < 0.06) { s.albedo = float3(0.25, 0.14, 0.06); s.alpha = 1.0; s.height = 0.4; }
        else if (hit) { s.albedo = float3(0.80, 0.80, 0.78) * (0.85 + 0.2 * pappus); s.alpha = 1.0; s.height = 0.5 + 0.3 * pappus; s.rough = 0.7; }
    } else if (idx == 6 || idx == 11) {               // clover head (white / red)
        if (r < 0.42) {
            float cid = 0.0, cid2 = 0.0;
            float2 off = cellLocal(p, int2(14, 14), sd + 3u, cid, cid2);
            float fl = 1.0 - smoothstep(0.15, 0.45, length(off));
            float3 cw = idx == 6 ? float3(0.80, 0.78, 0.70) : float3(0.55, 0.10, 0.28);
            float old = smoothstep(0.1, 0.42, -d.y + 0.1 * cid) * 0.8;   // older florets at the base brown
            float3 c = mix(cw, idx == 6 ? float3(0.36, 0.25, 0.14) : float3(0.25, 0.08, 0.1), old * (idx == 6 ? 1.0 : 0.6));
            s.albedo = c * (0.6 + 0.45 * fl) * (0.85 + 0.15 * (1.0 - r / 0.42)); s.alpha = 1.0;
            s.height = 0.4 + 0.4 * fl + 0.2 * (1.0 - r / 0.42); s.rough = 0.6;
        }
    } else if (idx == 7) {                            // white clover trefoil
        for (int i = 0; i < 3; i++) {
            float la = 1.5708 + float(i) * 2.0944;
            float2 dir = float2(cos(la), sin(la));
            float x = dot(d, dir), y = dot(d, float2(-dir.y, dir.x));
            float t = x / 0.44;
            if (t <= 0.0 || t >= 1.0) continue;
            float hw = 0.21 * pow(t, 0.6) * sqrt(max(1.0 - pow(t, 4.0), 0.0));
            float notch = (t > 0.85 && abs(y) < 0.03 * (t - 0.85) / 0.15) ? 1.0 : 0.0;
            if (abs(y) < hw && notch < 0.5) {
                float yn = y / hw;
                float3 c = plLeafColor(h01u(sd + uint(i)), p, sd + 4u, P);
                float chev = 1.0 - smoothstep(0.0, 0.06, abs(t - 0.38 - abs(yn) * 0.18));
                c = mix(c, float3(0.42, 0.48, 0.36), chev * 0.55 * step(abs(yn), 0.85));
                float mid = 1.0 - smoothstep(0.0, 0.07, abs(yn));
                float sec = 1.0 - smoothstep(0.0, 0.1, abs(fract(t * 9.0 - abs(yn) * 1.2) - 0.5) * 2.0);
                c *= 1.0 + 0.12 * mid + 0.06 * sec;
                s.albedo = c; s.alpha = 1.0; s.height = 0.6 + 0.15 * (1.0 - yn * yn) - 0.06 * mid; s.rough = 0.45;
            }
        }
    } else if (idx == 8 || idx == 10) {               // dandelion leaf / narrow stem leaf
        float y = p.y, x = p.x - 0.5;
        float hw;
        if (idx == 8) {
            float lobe = 0.55 + 0.45 * pow(fract(y * 5.0 + 0.3), 1.5);
            hw = 0.22 * pow(max(sin(3.14159 * pow(y, 0.75)), 0.0), 0.9) * lobe;
        } else {
            hw = 0.11 * pow(max(sin(3.14159 * pow(y, 0.8)), 0.0), 0.8);
        }
        if (y > 0.02 && y < 0.98 && abs(x) < max(hw, 0.012 * (1.0 - y))) {
            float yn = x / max(hw, 1e-3);
            float3 c = plLeafColor(0.4 + 0.4 * h01u(sd), p, sd + 5u, P);
            float mid = 1.0 - smoothstep(0.0, 0.1, abs(yn));
            c = mix(c, idx == 8 ? float3(0.42, 0.40, 0.22) : c * 1.3, mid * 0.6);
            float sec = 1.0 - smoothstep(0.0, 0.12, abs(fract(y * 12.0 - abs(yn) * 0.7) - 0.5) * 2.0);
            c *= 1.0 + 0.08 * sec;
            s.albedo = c; s.alpha = 1.0; s.height = 0.55 + 0.2 * (1.0 - yn * yn) - 0.08 * mid; s.rough = 0.5;
        }
    } else if (idx == 9) {                            // ivy leaf, five lobes
        float2 c0 = float2(0.5, 0.42);
        float2 q = p - c0; float rq = length(q); float aq = atan2(q.y, q.x);
        float re = 0.12;
        float lobeA[5] = {1.5708, 0.55, 2.59, -0.35, 3.49};
        float lobeL[5] = {0.44, 0.33, 0.33, 0.2, 0.2};
        float vein = 0.0;
        for (int i = 0; i < 5; i++) {
            float da = aq - lobeA[i]; da = atan2(sin(da), cos(da));
            re = max(re, lobeL[i] * pow(max(cos(da), 0.0), 6.0) + 0.1 * pow(max(cos(da), 0.0), 2.0));
            float2 ld = float2(cos(lobeA[i]), sin(lobeA[i]));
            float along = dot(q, ld), off = abs(dot(q, float2(-ld.y, ld.x)));
            if (along > 0.0) vein = max(vein, 1.0 - smoothstep(0.0, 0.008 + 0.006 * (1.0 - along / 0.4), off));
        }
        bool pet = abs(p.x - 0.5) < 0.01 && p.y < 0.42;
        if (rq < re) {
            float3 c = mix(float3(0.018, 0.045, 0.012), float3(0.04, 0.08, 0.02), h01u(sd + 3u)) * (0.85 + 0.3 * fine);
            c = mix(c, float3(0.28, 0.32, 0.24), vein * 0.75);
            s.albedo = c; s.alpha = 1.0; s.height = 0.6 + 0.1 * (1.0 - rq / re) - 0.06 * vein; s.rough = 0.28;
        } else if (pet) { s.albedo = float3(0.08, 0.06, 0.03); s.alpha = 1.0; s.height = 0.45; s.rough = 0.5; }
    }
    if (s.alpha < 0.5) s.height = 0.0;
    return s;
}

// Pinnate fern frond atlas, P.f.z columns of 1:2 frond cells: bare stipe, rachis, pinnae with lobed pinnules.
// colorA mature green, colorB fresh green, colorC brown; f.x browning, f.y triangular (bracken) outline.
S fernFrond(float2 uv, constant RFParams &P) {
    S s = defaults(); s.alpha = 0.0; s.rough = 0.55;
    float g = P.f.z > 0.5 ? P.f.z : 4.0;
    // Columns only: each cell is 1 wide by g tall in texels, so a strip of width = length / 2 maps
    // undistorted. p.x is remapped so the rachis sits at 0.5 with half-width 0.25 available.
    float2 cuv = uv * float2(g, 1.0); int2 cell = int2(floor(cuv));
    float2 p = float2((cuv.x - floor(cuv.x)) * 0.5 + 0.25, uv.y);
    uint sd = P.seed + uint(cell.x * 7);
    s.albedo = P.colorA.rgb;
    float bend = (h01u(sd) - 0.5) * 0.06;
    float y0 = 0.1;
    float rx = 0.5 + bend * p.y * p.y;
    float best = -1.0;
    // Rachis.
    float rw = 0.007 * (1.0 - 0.7 * p.y);
    if (abs(p.x - rx) < rw && p.y < 0.985) {
        s.alpha = 1.0; best = 0.9;
        s.albedo = mix(float3(0.10, 0.08, 0.03), P.colorA.rgb * 1.2, smoothstep(0.0, y0 * 2.0, p.y));
        s.height = 0.8; s.rough = 0.5;
    }
    int N = 22;
    for (int side = 0; side < 2; side++) {
        float sgn = side == 0 ? -1.0 : 1.0;
        for (int k = 0; k < N; k++) {
            uint pk = sd + uint(k) * 11u + uint(side) * 300u;
            float t = (float(k) + 0.5 + 0.35 * float(side)) / float(N);
            float yb = y0 + t * (0.97 - y0);
            float env = P.f.y > 0.5 ? pow(1.0 - t, 0.9) * smoothstep(0.0, 0.12, t) : pow(max(sin(3.14159 * pow(t, 0.7)), 0.0), 1.1);
            float L = 0.215 * env * (0.9 + 0.1 * h01u(pk));
            if (L < 0.02) continue;
            float2 base = float2(0.5 + bend * yb * yb, yb);
            float a = 1.1 - 0.35 * t + 0.1 * (h01u(pk + 1u) - 0.5);
            float2 dir = float2(sgn * sin(a), cos(a));
            float2 q = p - base;
            float x = dot(q, dir);
            if (x <= 0.0 || x >= L) continue;
            float y = dot(q, float2(-dir.y, dir.x));
            float sAl = x / L;
            float pinW = 0.032 * (0.55 + 0.45 * env) * (0.8 + 0.2 * h01u(pk + 2u));
            float nPin = 9.0;
            float lobes = 0.55 + 0.45 * pow(abs(sin(sAl * 3.14159 * nPin)), 0.7);
            float hw = pinW * pow(max(1.0 - sAl, 0.0), 0.7) * lobes * smoothstep(0.0, 0.06, sAl + 0.02);
            // Pinnules curve toward the pinna tip: shift the test line slightly.
            if (abs(y) > hw) continue;
            float hg = 0.5 + 0.02 * float(k);
            if (hg < best) continue;
            best = hg;
            float yn = y / max(hw, 1e-4);
            float var = h01u(pk + 3u);
            float3 c = mix(P.colorA.rgb, P.colorB.rgb, 0.25 + 0.5 * var * smoothstep(0.2, 1.0, sAl));
            c = mix(c, P.colorB.rgb, 0.4 * smoothstep(0.75, 1.0, t));           // fresh frond tip
            float brown = smoothstep(1.0 - P.f.x, 1.0, h01u(pk + 4u) * 0.6 + sAl * 0.5) * step(0.01, P.f.x);
            c = mix(c, P.colorC.rgb * (0.8 + 0.4 * var), brown);
            float midv = 1.0 - smoothstep(0.0, 0.1, abs(yn));
            float sori = 0.0;
            c *= (0.85 + 0.25 * fbm(p, int2(12, 12), 3, sd + 9u)) * (1.0 + 0.15 * midv);
            c *= 0.85 + 0.15 * (1.0 - abs(yn));
            s.albedo = c; s.alpha = 1.0;
            s.height = 0.55 + 0.25 * (1.0 - yn * yn) * lobes - 0.08 * midv + sori;
            s.rough = 0.5 + 0.2 * brown;
            s.ao = 0.75 + 0.25 * sAl;
        }
    }
    if (s.alpha < 0.5) s.height = 0.0;
    return s;
}

// Dry leaf litter atlas (P.f.z grid): oak, maple, beech and willow shapes, browns with decay and holes.
// colorA dark brown, colorB tan, colorC orange.
S leafLitter(float2 uv, constant RFParams &P) {
    S s = defaults(); s.alpha = 0.0; s.rough = 0.75;
    float g = P.f.z > 0.5 ? P.f.z : 4.0;
    float2 cuv = uv * g; int2 cell = int2(floor(cuv)); float2 p = cuv - floor(cuv);
    uint sd = P.seed + uint(cell.x * 7 + cell.y * 13);
    int type = int(h01u(sd) * 4.0);
    s.albedo = mix(P.colorA.rgb, P.colorB.rgb, 0.4);
    float y = (p.y - 0.06) / 0.9; float x = p.x - 0.5;
    float hw = 0.0; float inside = 0.0; float yn = 0.0;
    if (type == 3) {                                  // maple: palmate, 5 lobes from a point at 0.3
        float2 q = p - float2(0.5, 0.32); float rq = length(q); float aq = atan2(q.y, q.x);
        float re = 0.08;
        for (int i = 0; i < 5; i++) {
            float la = 1.5708 + (float(i) - 2.0) * 0.85;
            float da = aq - la; da = atan2(sin(da), cos(da));
            float len = (i == 2 ? 0.6 : (i == 1 || i == 3 ? 0.5 : 0.3));
            re = max(re, len * pow(max(cos(da), 0.0), 9.0) + 0.06);
        }
        re *= 1.0 - 0.05 * abs(sin(aq * 30.0));
        inside = rq < re ? 1.0 : 0.0; yn = rq / re;
        if (abs(x) < 0.008 && p.y < 0.32 && p.y > 0.04) { inside = 1.0; yn = 0.0; }
    } else {
        if (y > 0.0 && y < 1.0) {
            if (type == 0) hw = 0.3 * pow(max(sin(3.14159 * pow(y, 0.85)), 0.0), 0.8) * (0.62 + 0.38 * abs(cos(y * 3.14159 * 4.5)));
            else if (type == 1) hw = 0.3 * pow(max(sin(3.14159 * pow(y, 0.7)), 0.0), 0.7) * (1.0 - 0.04 * abs(sin(y * 80.0)));
            else hw = 0.12 * pow(max(sin(3.14159 * y), 0.0), 0.8);
        }
        if (abs(x) < hw) { inside = 1.0; yn = abs(x) / hw; }
        if (abs(x) < 0.008 && p.y > 0.01 && y < 0.2) { inside = 1.0; yn = 0.0; }
    }
    // Insect holes and broken edges.
    float4 w = worley(p, int2(10, 10), sd + 5u, 1.0);
    float hole = (1.0 - step(0.12 + 0.1 * h01u(sd + 6u), w.x)) * step(0.7, w.z);
    if (inside > 0.5 && hole < 0.5) {
        float v = h01u(sd + 1u);
        float3 c = mix(P.colorA.rgb, P.colorB.rgb, v);
        c = mix(c, P.colorC.rgb, step(0.75, h01u(sd + 2u)) * 0.8);
        float decay = smoothstep(0.0, 0.3, fbm(p, int2(5, 5), 4, sd + 7u));
        c = mix(c, P.colorA.rgb * 0.55, decay * 0.7);
        float vein = 1.0 - smoothstep(0.0, 0.025, abs(x));
        float sec = (type == 3) ? 0.0 : 1.0 - smoothstep(0.0, 0.1, abs(fract(y * 9.0 - abs(x) * 4.0) - 0.5) * 2.0);
        c *= 1.0 + 0.2 * vein - 0.08 * sec;
        c *= 1.0 - 0.3 * smoothstep(0.75, 1.0, yn);                // curled, darker edges
        c *= 0.85 + 0.3 * fbm(p, int2(16, 16), 3, sd + 8u);
        s.albedo = c; s.alpha = 1.0;
        s.height = 0.5 + 0.2 * yn * yn + 0.1 * vein - 0.05 * sec;
        s.rough = 0.7 + 0.1 * decay; s.ao = 0.8 + 0.2 * (1.0 - yn);
    } else {
        s.height = 0.0;
    }
    return s;
}

// Cushion moss, tiling: dense star-shaped shoots, colour patches. colorA dark, colorB bright, colorC brown.
// f.x brown patches, f.y shoot scale (cells per tile, default 90).
S moss(float2 uv, constant RFParams &P) {
    S s = defaults(); uint sd = P.seed;
    int fr = P.f.y > 1.0 ? int(P.f.y) : 90;
    float macro = fbm(uv, int2(3, 3), 4, sd + 1u);
    float3 base = mix(P.colorA.rgb, P.colorB.rgb, 0.35 + 0.4 * smoothstep(-0.35, 0.35, macro));
    float brown = smoothstep(0.1, 0.35, fbm(uv, int2(4, 4), 4, sd + 2u)) * P.f.x;
    base = mix(base, P.colorC.rgb, brown);
    float hmax = 0.0; float tip = 0.0;
    for (int layer = 0; layer < 3; layer++) {
        float cid = 0.0, cid2 = 0.0;
        int f = fr - layer * 17;
        float2 off = cellLocal(uv, int2(f, f), sd + 10u + uint(layer) * 23u, cid, cid2);
        float rr = length(off); float a = atan2(off.y, off.x) + cid * 6.28;
        float star = 0.42 * (0.55 + 0.45 * pow(abs(cos(a * 3.0)), 3.0));
        float h = max(0.0, 1.0 - rr / star) * (0.7 + 0.3 * cid2);
        if (h > hmax) { hmax = h; tip = cid2; }
    }
    float3 c = base * (0.35 + 0.85 * hmax) * (0.85 + 0.3 * tip);
    c = mix(c, c * float3(1.15, 1.2, 0.8), smoothstep(0.6, 1.0, hmax) * 0.5);
    s.albedo = c; s.height = 0.15 + 0.7 * hmax + 0.15 * macro;
    s.rough = 0.88 - 0.1 * hmax; s.ao = 0.45 + 0.55 * hmax;
    return s;
}

// Mushroom tissue, tiling. f.x mode: 0 cap (mottled, radial fibrils, f.y warts), 1 gills (dense stripes
// along v), 2 stalk (fibrous streaks). colorA main, colorB second, colorC spots. f.z roughness.
S fungus(float2 uv, constant RFParams &P) {
    S s = defaults(); uint sd = P.seed;
    int mode = int(P.f.x + 0.5);
    float rough = P.f.z > 0.0 ? P.f.z : 0.55;
    if (mode == 0) {
        float m = fbm(uv, int2(4, 4), 4, sd + 1u);
        float fib = fbm(uv, int2(48, 2), 2, sd + 2u);
        float3 c = mix(P.colorA.rgb, P.colorB.rgb, smoothstep(-0.25, 0.3, m));
        c *= 0.92 + 0.18 * fib;
        float4 w = worley(uv, int2(12, 12), sd + 3u, 0.9);
        float wart = (1.0 - smoothstep(0.08, 0.22, w.x)) * step(1.0 - P.f.y, w.z);
        c = mix(c, P.colorC.rgb, wart);
        s.albedo = c; s.height = 0.5 + 0.1 * m + 0.05 * fib + 0.3 * wart;
        s.rough = rough + 0.2 * wart; s.ao = 1.0;
    } else if (mode == 1) {
        float st = 0.5 + 0.5 * cos(uv.x * 6.2831853 * 40.0);
        float st2 = 0.5 + 0.5 * cos(uv.x * 6.2831853 * 80.0 + 1.0);
        float gill = max(pow(st, 3.0), 0.6 * pow(st2, 4.0));
        float3 c = mix(P.colorA.rgb * 0.45, P.colorA.rgb, gill);
        c *= 0.9 + 0.2 * fbm(uv, int2(8, 8), 3, sd + 4u);
        s.albedo = c; s.height = gill; s.rough = 0.7; s.ao = 0.4 + 0.6 * gill;
    } else {
        float st = fbm(uv, int2(32, 2), 3, sd + 5u);
        float3 c = mix(P.colorA.rgb, P.colorB.rgb, 0.5 + st);
        c *= 0.9 + 0.2 * fbm(uv, int2(6, 6), 3, sd + 6u);
        s.albedo = c; s.height = 0.5 + 0.25 * st; s.rough = rough + 0.1; s.ao = 1.0;
    }
    return s;
}

// Herbaceous stems, tiling: longitudinal ridges (along v), colour drift, small dry flecks.
// colorA base, colorB ridge highlight, colorC flecks; f.x fleck amount.
S plantStem(float2 uv, constant RFParams &P) {
    S s = defaults(); uint sd = P.seed;
    float ridge = 0.5 + 0.5 * cos(uv.x * 6.2831853 * 5.0);
    float drift = fbm(uv, int2(2, 6), 4, sd + 1u);
    float3 c = mix(P.colorA.rgb, P.colorB.rgb, 0.3 * ridge + 0.4 * smoothstep(-0.3, 0.3, drift));
    float fleck = (1.0 - smoothstep(0.05, 0.15, worley(uv, int2(6, 24), sd + 2u, 1.0).x)) * P.f.x;
    c = mix(c, P.colorC.rgb, fleck);
    s.albedo = c; s.height = 0.5 + 0.25 * ridge; s.rough = 0.5 + 0.1 * (1.0 - ridge); s.ao = 1.0;
    return s;
}
"""#
