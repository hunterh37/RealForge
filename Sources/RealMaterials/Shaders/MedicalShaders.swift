// Hospital programs (RealityHD 5): sheet vinyl flooring, nonwoven drapes and exam paper, glazed wall
// tile, patient-monitor display, printed pharmacy labels. Uses the of_* helpers from OfficeShaders.

let metalMedical = #"""
// ---------------------------------------------------------------- medical / hospital
// Homogeneous sheet vinyl: a base with directional chips of two colors, heat-welded seams, polish
// sheen and scuffs. colorA base, colorB chip 1 (a = share), colorC chip 2 (a = share).
// f.x chips per tile (density), f.y seam (1 = weld rod at u = 0, one sheet per tile across u),
// f.z roughness, f.w scuffs and traffic wear.
S sheetVinyl(float2 uv, constant RFParams &P) {
    S s = defaults(); uint sd = P.seed;
    float macro = fbm(uv, int2(3, 3), 4, sd + 1u);
    float mid = fbm(uv, int2(18, 18), 3, sd + 2u);
    float3 c = P.colorA.rgb * (0.95 + 0.07 * macro + 0.03 * mid);
    int F = max(8, int(P.f.x));
    // Two chip layers: elongated flakes stretched along u (calendered), random size and hue.
    for (int layer = 0; layer < 2; layer++) {
        float cid = 0.0, cid2 = 0.0;
        int fr = F + layer * F / 2;
        float2 off = cellLocal(uv, int2(fr, fr * 2), sd + 10u + uint(layer) * 7u, cid, cid2);
        float share = layer == 0 ? P.colorB.a : P.colorC.a;
        if (cid > share) continue;
        float2 q = rot2(off, (cid2 - 0.5) * 0.5);
        float L = 0.35 + 0.4 * cid2, W = 0.12 + 0.1 * fract(cid * 13.0);
        float d = length(q / float2(L, W * 2.0));
        float edge = fbm(uv * float2(1.0, 2.0) + off * 0.01, int2(fr * 3, fr * 6), 2, sd + 20u + uint(layer)) * 0.35;
        float m = 1.0 - smoothstep(0.8 + edge, 1.0 + edge, d);
        float3 chip = (layer == 0 ? P.colorB.rgb : P.colorC.rgb) * (0.85 + 0.3 * fract(cid2 * 7.0));
        c = mix(c, chip, m * 0.6);
    }
    // Fine speckle.
    float sp = h01(int2(uv * 1024.0), sd + 31u);
    c *= 0.97 + 0.06 * sp;
    float h = 0.5 + 0.01 * mid;
    float rough = P.f.z * (0.92 + 0.12 * mid);
    // Heat-welded seam: a 4 mm weld rod line at u = 0 (and u = 1), slightly darker and glossier.
    if (P.f.y > 0.5) {
        float du = min(uv.x, 1.0 - uv.x);
        float rod = 1.0 - smoothstep(0.0012, 0.0022, du);
        c = mix(c, P.colorA.rgb * 0.82, rod * 0.8);
        h -= rod * 0.03; rough -= rod * 0.12;
        float gap = 1.0 - smoothstep(0.0, 0.0004, abs(du - 0.0022));
        c *= 1.0 - gap * 0.3;
    }
    // Traffic: polished lanes and black heel scuffs.
    float lane = smoothstep(0.1, 0.5, fbm(uv, int2(2, 2), 3, sd + 41u)) * P.f.w;
    rough = mix(rough, rough * 0.7, lane);
    float cid = 0.0, cid2 = 0.0;
    float2 so = cellLocal(uv, int2(14, 14), sd + 51u, cid, cid2);
    if (cid < 0.35 * P.f.w) {
        float2 q = rot2(so, cid2 * 6.2831);
        float arc = abs(length(q - float2(0.0, 0.6)) - 0.6);
        float along = 1.0 - smoothstep(0.1, 0.3, abs(q.x));
        float sc = (1.0 - smoothstep(0.004, 0.02, arc)) * along;
        c = mix(c, float3(0.05), sc * 0.55);
    }
    c = mix(c, c * 0.92 + 0.01, lane * 0.25);
    s.albedo = c; s.height = h; s.rough = clamp(rough, 0.08, 1.0); s.ao = 1.0; s.metal = 0.0;
    return s;
}

// Nonwoven sheet: spunbond fibers with a thermal-bond dot grid (surgical drapes, gowns, wraps) or a
// creped paper (exam table paper, f.y > 0). colorA base, colorB fiber shade.
// f.x bond dots per tile, f.y crepe amount, f.z roughness, f.w fold creases (grid of drape folds).
S nonwoven(float2 uv, constant RFParams &P) {
    S s = defaults(); uint sd = P.seed;
    float fibers = 0.0;
    for (int i = 0; i < 3; i++) {
        float a = 0.6 + float(i) * 1.1;
        float2 r = rot2(uv, a);
        fibers += gnoise(r * float2(40.0, 900.0), int2(40, 900), sd + uint(i) * 11u) * 0.33;
    }
    float cloud = fbm(uv, int2(24, 24), 4, sd + 5u);
    float3 c = mix(P.colorA.rgb, P.colorB.rgb, sat(0.4 + 0.6 * fibers + 0.5 * cloud));
    float h = 0.5 + fibers * 0.12 + cloud * 0.08;
    // Bond pattern: small embossed diamonds pressed into the web.
    int D = max(4, int(P.f.x));
    float2 g = uv * float(D); float2 gi = floor(g); float2 gf = g - gi - 0.5;
    if (fmod(gi.y, 2.0) > 0.5) { gf.x = fract(g.x + 0.5) - 0.5; }
    float dia = abs(gf.x) + abs(gf.y);
    float bond = 1.0 - smoothstep(0.16, 0.22, dia);
    h -= bond * 0.15 * (1.0 - P.f.y); c *= 1.0 - bond * 0.05 * (1.0 - P.f.y);
    // Crepe: fine wrinkles across v, irregular.
    if (P.f.y > 0.0) {
        float cr = gnoise(float2(uv.x * 30.0, uv.y * 420.0 + 6.0 * fbm(uv, int2(6, 6), 2, sd + 7u)), int2(30, 420), sd + 8u);
        h += cr * 0.2 * P.f.y; c *= 1.0 + cr * 0.04 * P.f.y;
    }
    // Fold creases: drape packs unfolded on the table keep their fold lines.
    if (P.f.w > 0.0) {
        float2 fq = fract(uv * 4.0);
        float fx = 1.0 - smoothstep(0.0, 0.012, min(fq.x, 1.0 - fq.x));
        float fy = 1.0 - smoothstep(0.0, 0.012, min(fq.y, 1.0 - fq.y));
        float cr = max(fx, fy) * P.f.w;
        h += cr * 0.25; c *= 1.0 - cr * 0.08;
    }
    s.albedo = c; s.height = sat(h); s.rough = P.f.z; s.ao = 0.9 + 0.1 * cloud; s.metal = 0.0;
    return s;
}

// Glazed ceramic wall tile with cement grout. colorA glaze, colorB grout, colorC grime (a = amount).
// f.x tiles across u per tile, f.y tiles across v per tile, f.z grout width (fraction of a tile),
// f.w glaze variation between tiles.
S wallTile(float2 uv, constant RFParams &P) {
    S s = defaults(); uint sd = P.seed;
    float2 n = float2(max(1.0, P.f.x), max(1.0, P.f.y));
    float2 g = uv * n; float2 gi = floor(g); float2 gf = g - gi;
    int2 id = wrapc(int2(gi), int2(n));
    float gw = P.f.z;
    float dx = min(gf.x, 1.0 - gf.x) / n.x, dy = min(gf.y, 1.0 - gf.y) / n.y;   // in tile units of uv
    float d = min(dx, dy) * max(n.x, n.y);
    float grout = 1.0 - smoothstep(gw * 0.5, gw * 0.5 + 0.01, d);
    float bevel = 1.0 - smoothstep(gw * 0.5, gw * 0.5 + 0.05, d);
    float tv = h01(id, sd + 3u);
    float3 glaze = P.colorA.rgb * (1.0 + (tv - 0.5) * P.f.w);
    float wave = fbm(uv, int2(int(n.x) * 2, int(n.y) * 2), 3, sd + 5u);
    glaze *= 0.98 + 0.03 * wave;
    float3 gr = P.colorB.rgb * (0.9 + 0.2 * fbm(uv, int2(200, 200), 2, sd + 7u));
    float grime = P.colorC.a * smoothstep(0.0, 0.6, fbm(uv, int2(3, 3), 3, sd + 9u));
    gr = mix(gr, P.colorC.rgb, grime);
    s.albedo = mix(glaze, gr, grout);
    s.height = 0.6 - bevel * 0.15 - grout * 0.3 + wave * 0.01;
    s.rough = mix(0.12 + 0.05 * wave, 0.85, grout);
    s.ao = 1.0 - grout * 0.35; s.metal = 0.0;
    return s;
}

// ---- vitalsUI helpers. Seven-segment digit in a cell p in [0,1] x [0,1.8] (y down). Returns coverage.
float md_seg7(float2 p, int dg, float aa) {
    if (dg < 0) return 0.0;
    // segments a b c d e f g as bits
    const uint masks[10] = {0x3Fu, 0x06u, 0x5Bu, 0x4Fu, 0x66u, 0x6Du, 0x7Du, 0x07u, 0x7Fu, 0x6Fu};
    uint m = masks[dg % 10];
    float t = 0.13, r = 0.05, cov = 0.0;
    float2 hs = float2(0.36, t * 0.5), vs = float2(t * 0.5, 0.36);
    float2 ctr[7] = {float2(0.5, 0.1), float2(0.9, 0.5), float2(0.9, 1.3), float2(0.5, 1.7), float2(0.1, 1.3), float2(0.1, 0.5), float2(0.5, 0.9)};
    for (int i = 0; i < 7; i++) {
        if ((m >> uint(i) & 1u) == 0u) continue;
        bool hz = (i == 0 || i == 3 || i == 6);
        float2 q = float2(p.x - 0.12 * (p.y - 0.9) * -0.15, p.y);
        cov = max(cov, of_fill(of_box(q, ctr[i], hz ? hs : vs, r * 0.5), aa));
    }
    return cov;
}
// Number of up to 3 digits right-aligned ending at x1; h = digit height in screen units.
float md_number(float2 q, float x1, float y0, float h, int v, float aa) {
    float w = h / 1.8 * 1.15; float cov = 0.0; int n = v;
    for (int i = 0; i < 3; i++) {
        float x0 = x1 - w * float(i + 1);
        float2 p = (q - float2(x0, y0)) / (h / 1.8);
        if (p.x > -0.1 && p.x < 1.1 && p.y > -0.1 && p.y < 1.9) cov = max(cov, md_seg7(p, n % 10, aa * 1.8 / h));
        n /= 10; if (n == 0) break;
    }
    return cov;
}
float md_ecg(float t) {
    float p = 0.12 * exp(-pow((t - 0.16) / 0.035, 2.0));
    float q = -0.12 * exp(-pow((t - 0.285) / 0.009, 2.0));
    float r = 1.0 * exp(-pow((t - 0.305) / 0.011, 2.0));
    float s = -0.28 * exp(-pow((t - 0.33) / 0.011, 2.0));
    float tw = 0.28 * exp(-pow((t - 0.58) / 0.06, 2.0));
    return p + q + r + s + tw;
}
float md_pleth(float t) {
    return 0.95 * exp(-pow((t - 0.25) / 0.09, 2.0)) * (t > 0.25 ? 1.0 : 1.0) + 0.35 * exp(-pow((t - 0.52) / 0.08, 2.0)) - 0.1 * exp(-pow((t - 0.42) / 0.03, 2.0));
}
// Draws a trace y = base - amp * f(x) in band [y0, y1]; returns coverage.
float md_trace(float2 q, float x0, float x1, float yb, float amp, float period, int kind, float sweep, float aa) {
    if (q.x < x0 || q.x > x1) return 0.0;
    if (abs(q.x - sweep) < 0.012) return 0.0;   // erase bar ahead of the sweep
    // Coverage of the polyline through the samples one pixel either side: vertical runs (QRS) fill
    // exactly between neighbouring samples instead of smearing past the peak.
    float e = aa * 0.6;
    float t0 = fract((q.x - x0) / period), tl = fract((q.x - e - x0) / period), tr = fract((q.x + e - x0) / period);
    float f0, fl, fr;
    if (kind == 0) { f0 = md_ecg(t0); fl = md_ecg(tl); fr = md_ecg(tr); }
    else if (kind == 1) { f0 = md_pleth(t0); fl = md_pleth(tl); fr = md_pleth(tr); }
    else { f0 = 0.5 + 0.5 * sin(t0 * 6.2831); fl = 0.5 + 0.5 * sin(tl * 6.2831); fr = 0.5 + 0.5 * sin(tr * 6.2831); }
    float y0 = yb - amp * f0, yl = yb - amp * 0.5 * (fl + f0), yr = yb - amp * 0.5 * (fr + f0);
    float lo = min(y0, min(yl, yr)), hi = max(y0, max(yl, yr));
    float d = max(max(lo - q.y, q.y - hi), 0.0);
    return 1.0 - smoothstep(0.0011, 0.0011 + aa * 1.2, d);
}

// Bedside patient monitor screen (emissive): ECG II, pleth, respiration and arterial traces with a
// sweep bar, numerics (HR, SpO2, NIBP, RR, Temp) in parameter colors, header bar and grid.
// UVs 0...1 across a 16:10 panel, v down (unlit display path). f.x heart rate (bpm), f.y SpO2 (%),
// f.z sweep position 0...1, f.w alarm banner (1 = yellow alarm). colorA background.
S vitalsUI(float2 uv, constant RFParams &P) {
    S s = defaults(); uint sd = P.seed;
    float2 q = float2(uv.x * 1.6, uv.y);
    float aa = 1.6 / float(P.size);
    float3 c = P.colorA.rgb;
    // Faint grid behind the traces.
    float2 gq = fract(q * float2(40.0, 25.0));
    float grid = 1.0 - smoothstep(0.0, 0.04, min(min(gq.x, 1.0 - gq.x), min(gq.y, 1.0 - gq.y)));
    if (q.x < 1.08 && q.y > 0.07) c += float3(0.02, 0.03, 0.03) * grid;
    // Header bar: bed label, patient id text, clock.
    if (q.y < 0.06) {
        c = mix(c, float3(0.12, 0.14, 0.18), 0.9);
        if (P.f.w > 0.5) c = mix(c, float3(0.95, 0.75, 0.05), of_fill(of_box(q, float2(0.8, 0.03), float2(0.18, 0.022), 0.004), aa));
        int w; float t1 = of_line(q.x - 0.03, (q.y - 0.015) / 0.03, 0.012, sd + 3u, 0.36, w);
        float t2 = of_line(q.x - 1.36, (q.y - 0.015) / 0.03, 0.012, sd + 4u, 0.2, w);
        c = mix(c, float3(0.85), max(t1, t2));
    }
    float hr = max(30.0, P.f.x);
    float period = 0.9 * 60.0 / hr * 0.25;   // screen units per beat (25 mm/s sweep feel)
    float sweep = 0.02 + P.f.z * 1.04;
    float3 green = float3(0.15, 0.95, 0.35), cyan = float3(0.2, 0.85, 1.0), yellow = float3(1.0, 0.9, 0.2), red = float3(1.0, 0.25, 0.25), white = float3(0.92);
    // Traces, left 1.08 of the width.
    c = mix(c, green, md_trace(q, 0.02, 1.06, 0.26, 0.15, period, 0, sweep, aa));
    c = mix(c, red, md_trace(q, 0.02, 1.06, 0.50, 0.10, period, 1, sweep, aa));
    c = mix(c, cyan, md_trace(q, 0.02, 1.06, 0.72, 0.11, period, 1, sweep, aa) * 1.0);
    c = mix(c, yellow, md_trace(q, 0.02, 1.06, 0.94, 0.08, period * 4.5, 2, sweep, aa));
    // Trace labels.
    int w;
    float l1 = of_line(q.x - 0.025, (q.y - 0.085) / 0.022, 0.009, sd + 11u, 0.04, w);
    float l2 = of_line(q.x - 0.025, (q.y - 0.335) / 0.022, 0.009, sd + 12u, 0.05, w);
    float l3 = of_line(q.x - 0.025, (q.y - 0.565) / 0.022, 0.009, sd + 13u, 0.05, w);
    float l4 = of_line(q.x - 0.025, (q.y - 0.795) / 0.022, 0.009, sd + 14u, 0.04, w);
    c = mix(c, green, l1); c = mix(c, red, l2); c = mix(c, cyan, l3); c = mix(c, yellow, l4);
    // Numerics column.
    if (q.x > 1.1) {
        float sepY[4] = {0.3, 0.52, 0.76, 1.0};
        for (int i = 0; i < 4; i++) c = mix(c, float3(0.25), 1.0 - smoothstep(0.0, aa * 1.5, abs(q.y - sepY[i])));
        c = mix(c, float3(0.25), 1.0 - smoothstep(0.0, aa * 1.5, abs(q.x - 1.1)));
        int hri = int(hr + 0.5), spo = int(clamp(P.f.y, 50.0, 100.0) + 0.5);
        c = mix(c, green, md_number(q, 1.56, 0.1, 0.17, hri, aa));
        c = mix(c, red, md_number(q, 1.38, 0.36, 0.09, 118, aa));
        c = mix(c, red, md_number(q, 1.56, 0.39, 0.06, 76, aa));
        c = mix(c, red, of_fill(of_box(rot2(q - float2(1.408, 0.415), -0.35), float2(0.0), float2(0.0035, 0.04), 0.001), aa));
        c = mix(c, cyan, md_number(q, 1.56, 0.56, 0.15, spo, aa));
        c = mix(c, yellow, md_number(q, 1.42, 0.8, 0.12, 16, aa));
        c = mix(c, white, md_number(q, 1.56, 0.86, 0.06, 37, aa) * 0.9);
        float u1 = of_line(q.x - 1.12, (q.y - 0.08) / 0.022, 0.009, sd + 21u, 0.06, w);
        float u2 = of_line(q.x - 1.12, (q.y - 0.315) / 0.022, 0.009, sd + 22u, 0.07, w);
        float u3 = of_line(q.x - 1.12, (q.y - 0.535) / 0.022, 0.009, sd + 23u, 0.06, w);
        float u4 = of_line(q.x - 1.12, (q.y - 0.775) / 0.022, 0.009, sd + 24u, 0.04, w);
        c = mix(c, green, u1); c = mix(c, red, u2); c = mix(c, cyan, u3); c = mix(c, yellow, u4);
        // Heart glyph blinking dot next to HR.
        c = mix(c, red, of_fill(length(q - float2(1.15, 0.24)) - 0.008, aa));
    }
    // Pixel structure (sub-pixel stripes) at close range.
    float px = fract(uv.x * float(P.size) / 1.0);
    c *= 0.94 + 0.06 * smoothstep(0.1, 0.4, px);
    s.albedo = c; s.rough = 0.3; s.height = 0.5; s.ao = 1.0; s.metal = 0.0;
    return s;
}

// Printed self-adhesive label: paper with a color band, greeked text lines, an optional barcode and
// a hairline border. UVs 0...1 across the label (tileSize 1), v down the label. colorA paper,
// colorB band, colorC ink. f.x band height (fraction of v), f.y barcode (1 = yes), f.z text lines,
// f.w gloss (0 matte paper, 1 film).
S medLabel(float2 uv, constant RFParams &P) {
    S s = defaults(); uint sd = P.seed;
    float aa = 1.0 / float(P.size);
    float3 c = P.colorA.rgb * (0.97 + 0.03 * fbm(uv, int2(40, 40), 2, sd + 1u));
    float band = P.f.x;
    if (uv.y < band) c = P.colorB.rgb;
    // Text in the band (reversed out) and below it.
    int w;
    if (band > 0.05) {
        float t = of_line(uv.x - 0.06, (uv.y - band * 0.25) / (band * 0.5), 0.035, sd + 5u, 0.6, w);
        c = mix(c, P.colorA.rgb, t);
    }
    int lines = max(1, int(P.f.z));
    float y0 = band + 0.06, y1 = P.f.y > 0.5 ? 0.72 : 0.94;
    float lh = (y1 - y0) / float(lines);
    if (uv.y > y0 && uv.y < y1) {
        float row = floor((uv.y - y0) / lh);
        float big = row < 1.0 ? 1.3 : 1.0;
        float t = of_line(uv.x - 0.06, ((uv.y - y0) / lh - row) * 1.2 - 0.1, 0.022 * big, sd + 9u + uint(row) * 17u, 0.55 + 0.35 * h01u(sd + uint(row)), w);
        c = mix(c, P.colorC.rgb, t * 0.95);
    }
    if (P.f.y > 0.5 && uv.y > 0.76 && uv.y < 0.94 && uv.x > 0.08 && uv.x < 0.7) {
        float bx = (uv.x - 0.08) / 0.62 * 95.0;
        float bar = step(0.5, h01u(sd + uint(floor(bx)) * 7u));
        c = mix(c, P.colorC.rgb, bar);
    }
    // Hairline border.
    float e = min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y));
    c = mix(c, c * 0.8, 1.0 - smoothstep(0.0, aa * 3.0, e));
    s.albedo = c; s.height = 0.5; s.rough = mix(0.75, 0.25, P.f.w); s.ao = 1.0; s.metal = 0.0;
    return s;
}
"""#
