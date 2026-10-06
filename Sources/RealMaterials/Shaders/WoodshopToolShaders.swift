// Woodshop hand-tool programs: the printed tape-measure blade.

let metalWoodshopTools = #"""
// ---------------------------------------------------------------- woodshop hand tools
// Distance from p to segment ab minus half-width w (negative inside the stroke).
float tr_seg(float2 p, float2 a, float2 b, float w) {
    float2 pa = p - a, ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h) - w;
}
// Seven-segment stroke digit in a w x h box with its lower-left corner at the origin.
float tr_digit(float2 p, int d, float w, float h, float t) {
    const int masks[10] = {63, 6, 91, 79, 102, 109, 125, 7, 127, 111};
    int m = masks[clamp(d, 0, 9)];
    float2 A = float2(0, h), B = float2(w, h), C = float2(0, h * 0.5), D = float2(w, h * 0.5), E = float2(0, 0), F = float2(w, 0);
    float r = 9.0;
    if (d == 1) return tr_seg(p, float2(w * 0.55, 0), float2(w * 0.55, h), t);
    if (m & 1)  r = min(r, tr_seg(p, A, B, t));
    if (m & 2)  r = min(r, tr_seg(p, B, D, t));
    if (m & 4)  r = min(r, tr_seg(p, D, F, t));
    if (m & 8)  r = min(r, tr_seg(p, E, F, t));
    if (m & 16) r = min(r, tr_seg(p, C, E, t));
    if (m & 32) r = min(r, tr_seg(p, A, C, t));
    if (m & 64) r = min(r, tr_seg(p, C, D, t));
    return r;
}
// Tape-measure blade print. One tile is 16 inches along U (tileSize 0.4064 m); the 1 in blade width is
// 1/16 of the tile across V, so the strip repeats 16 times down the texture (v' = fract(v * 16)).
// Ticks at 1/16 in hierarchy from the top edge (v' = 1) and a shorter row from the bottom edge, inch
// numerals centered on each inch line, the 16 in stud mark boxed in red.
// colorA blade lacquer, colorB ink, colorC stud red. f.x roughness, f.y ink wear, f.z tick scale, f.w numerals (1 on).
S tapeRule(float2 uv, constant RFParams &P) {
    S s = defaults(); uint sd = P.seed;
    float2 p = float2(uv.x * 16.0, fract(uv.y * 16.0));          // inches along, 0...1 across
    float aa = 16.0 / float(P.size);                              // one texel in inches
    float3 c = P.colorA.rgb * (0.96 + 0.05 * fbm(uv, int2(16, 64), 3, sd + 1u));
    float ink = 0.0;
    float L = max(P.f.z, 0.5);
    // Graduations.
    float xi = p.x * 16.0, k = round(xi);
    int ki = int(k) & 255;
    float len = (ki % 16 == 0) ? 0.40 : (ki % 8 == 0 ? 0.30 : (ki % 4 == 0 ? 0.22 : (ki % 2 == 0 ? 0.16 : 0.11)));
    float hw = (ki % 16 == 0) ? 0.0075 : (ki % 4 == 0 ? 0.0055 : 0.0045);
    float dx = abs(xi - k) / 16.0;
    float tickX = 1.0 - smoothstep(hw - aa * 0.5, hw + aa * 0.5, dx);
    float top = 1.0 - smoothstep(len * L - aa, len * L, 1.0 - p.y);
    float bot = 1.0 - smoothstep(len * L * 0.55 - aa, len * L * 0.55, p.y);
    ink = max(ink, tickX * max(top, bot));
    // Inch numerals and the stud box.
    float n = round(p.x);
    int ni = int(n) & 15;
    int label = ni == 0 ? 16 : ni;
    float gh = 0.26, gw = 0.12, gap = 0.055, gt = 0.018, y0 = 0.29;
    int digits = label >= 10 ? 2 : 1;
    float total = float(digits) * gw + float(digits - 1) * gap;
    float2 q = float2(p.x - n + total * 0.5, p.y - y0);
    bool stud = ni == 0;
    if (stud) {
        float2 bq = abs(float2(p.x - n, p.y - (y0 + gh * 0.5))) - float2(total * 0.5 + 0.06, gh * 0.5 + 0.06);
        float box = 1.0 - smoothstep(-aa, aa, max(bq.x, bq.y));
        c = mix(c, P.colorC.rgb, box);
    }
    if (P.f.w > 0.5) {
        float dd = 9.0;
        if (digits == 2) {
            dd = min(dd, tr_digit(q, label / 10, gw, gh, gt));
            dd = min(dd, tr_digit(q - float2(gw + gap, 0), label % 10, gw, gh, gt));
        } else {
            dd = tr_digit(q, label, gw, gh, gt);
        }
        ink = max(ink, 1.0 - smoothstep(-aa * 0.5, aa * 0.5, dd));
    }
    // Ink wear: rubbed thin where the blade drags over the case lip.
    float wear = P.f.y * sat(fbm(uv, int2(32, 128), 3, sd + 7u) * 2.0 + 0.2);
    ink *= 1.0 - wear * 0.6;
    c = mix(c, P.colorB.rgb, ink);
    // Painted edges darken slightly where the coating thins.
    float edge = min(p.y, 1.0 - p.y);
    c *= 0.82 + 0.18 * smoothstep(0.0, 0.04, edge);
    s.albedo = c;
    s.height = 0.5 + 0.04 * ink + 0.01 * fbm(uv, int2(64, 256), 2, sd + 3u);
    s.rough = mix(P.f.x, P.f.x + 0.15, ink) + 0.1 * wear;
    s.ao = 1.0; s.metal = 0.0;
    return s;
}
"""#
