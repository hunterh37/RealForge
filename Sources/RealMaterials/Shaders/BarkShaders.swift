// Bark programs: barkOak, barkBirch, barkPine, barkSmooth, barkAspen, barkDead.

let metalBark = #"""
// ---------------------------------------------------------------- bark
S barkOak(float2 uv, constant RFParams &P) {
    S s = defaults(); uint sd = P.seed;
    // Mature oak: long vertical ridges (about 3 cm wide, 10 to 20 cm long) split by deep furrows, with
    // horizontal cracks breaking the ridges into blocks. Ridges are elongated Worley cells; furrows are the
    // cell borders. Domain warp makes them meander and interlace.
    float2 warp = float2(fbm(uv, int2(3, 4), 4, sd + 1u), fbm(uv, int2(3, 3), 3, sd + 2u));
    float2 q = uv + warp * float2(0.06, 0.02);
    float4 w = worley(q, int2(16, 2), sd + 3u, 0.95);
    float4 w2 = worley(q, int2(32, 6), sd + 4u, 0.9);
    // Furrow width varies along the trunk so ridges merge and split.
    float edge = (w.y - w.x) * (0.8 + 0.5 * fbm(uv, int2(8, 3), 2, sd + 5u));
    float ridge = smoothstep(0.03, 0.3, edge);                         // 0 in the furrow, 1 on the ridge top
    float crack = 1.0 - smoothstep(0.0, 0.07, w2.y - w2.x);          // finer splits across ridges
    crack *= smoothstep(0.25, 0.6, ridge) * step(0.45, w2.z);
    float fib = fbm(uv, int2(64, 8), 4, sd + 6u);                    // vertical fibres
    float fine = fbm(uv, int2(32, 32), 3, sd + 7u);
    float top = sqrt(ridge) * (0.85 + 0.3 * w.z);
    s.height = top * 0.7 - crack * 0.18 + fib * 0.08 + fine * 0.06;
    float3 plateCol = P.colorA.rgb * (0.78 + 0.4 * w.z) * (0.88 + 0.3 * fine) * (0.92 + 0.2 * fib);
    float3 wallCol = mix(P.colorB.rgb, P.colorA.rgb * 0.6, 0.6) * (0.85 + 0.3 * fib);
    s.albedo = mix(P.colorB.rgb * (0.8 + 0.3 * fib), wallCol, smoothstep(0.0, 0.12, ridge));
    s.albedo = mix(s.albedo, plateCol, smoothstep(0.3, 0.75, ridge));
    s.albedo = mix(s.albedo, P.colorB.rgb, crack * 0.7);
    float lichen = smoothstep(0.1, 0.32, fbm(uv, int2(3, 4), 5, sd + 11u) + fine * 0.35) * smoothstep(0.55, 0.9, ridge);
    s.albedo = mix(s.albedo, P.colorC.rgb * (0.8 + 0.4 * fib), lichen * P.f.x);
    float moss = smoothstep(0.1, 0.35, fbm(uv, int2(2, 2), 4, sd + 12u)) * (1.0 - ridge) * P.f.y;
    s.albedo = mix(s.albedo, float3(0.03, 0.055, 0.012), moss);
    s.rough = mix(0.97, 0.86, ridge) - lichen * 0.05;
    s.ao = mix(0.2, 1.0, smoothstep(0.0, 0.6, ridge)) * (1.0 - crack * 0.4);
    return s;
}
S barkBirch(float2 uv, constant RFParams &P) {
    S s = defaults(); uint sd = P.seed;
    float n = fbm(uv, int2(4, 4), 5, sd + 1u);
    float streak = fbm(uv, int2(3, 24), 3, sd + 2u);
    float3 base = P.colorA.rgb * (0.9 + 0.15 * n) + float3(0.02, 0.0, -0.02) * streak;
    // Lenticels: short horizontal dashes, one per Worley cell row.
    float4 lw = worley(uv, int2(5, 38), sd + 3u, 0.9);
    float2 lp = uv * float2(5.0, 38.0);
    float thin = 1.0 - smoothstep(0.05, 0.22, abs(fract(lp.y + lw.w * 0.5) - 0.5));
    float lent = smoothstep(0.42, 0.15, lw.x) * step(0.4, lw.z) * thin;
    // Dark diamond scars and rough black patches.
    float scar = smoothstep(0.32, 0.5, fbm(uv, int2(3, 5), 5, sd + 4u) + 0.25 * fbm(uv, int2(12, 6), 3, sd + 9u));
    float peel = smoothstep(0.2, 0.45, fbm(uv, int2(4, 10), 4, sd + 5u)) * (1.0 - scar);
    s.albedo = mix(base, P.colorC.rgb, peel * 0.6);
    s.albedo = mix(s.albedo, P.colorB.rgb, max(lent * 0.85, scar));
    s.height = 0.6 + n * 0.1 - lent * 0.3 - scar * (0.35 + 0.2 * fbm(uv, int2(24, 24), 3, sd + 6u)) + peel * 0.08;
    s.rough = mix(0.55, 0.92, max(scar, lent));
    s.ao = mix(1.0, 0.55, scar);
    return s;
}
S barkPine(float2 uv, constant RFParams &P) {
    S s = defaults(); uint sd = P.seed;
    float2 warp = float2(fbm(uv, int2(2, 2), 3, sd + 1u), fbm(uv, int2(2, 2), 3, sd + 2u)) * 0.08;
    float4 w = worley(uv + warp, int2(6, 4), sd + 3u, 0.9);
    float edge = w.y - w.x;
    float plate = smoothstep(0.03, 0.22, edge);
    float layer = floor(fbm(uv, int2(12, 8), 3, sd + 4u) * 6.0 + 3.0) / 6.0;   // flaky stacked layers
    float fine = fbm(uv, int2(40, 40), 3, sd + 5u);
    s.height = plate * (0.55 + 0.25 * layer + 0.15 * w.z) + fine * 0.08;
    float3 plateCol = mix(P.colorA.rgb, P.colorC.rgb, smoothstep(0.3, 0.7, layer + w.z * 0.3));
    s.albedo = mix(P.colorB.rgb, plateCol * (0.85 + 0.3 * fine), smoothstep(0.05, 0.6, plate));
    s.rough = mix(0.95, 0.85, plate);
    s.ao = mix(0.25, 1.0, smoothstep(0.0, 0.7, s.height));
    return s;
}
// Smooth thin bark (beech, hornbeam, Japanese maple): grey skin with mottling, faint horizontal
// lenticel bands, dark eye scars where twigs fell. Knobs: x lichen (colorC), y band strength.
S barkSmooth(float2 uv, constant RFParams &P) {
    S s = defaults(); uint sd = P.seed;
    float mottle = fbm(uv, int2(5, 3), 5, sd + 1u);
    float fine = fbm(uv, int2(48, 48), 3, sd + 2u);
    float patch = smoothstep(0.05, 0.35, fbm(uv, int2(4, 3), 4, sd + 3u));
    float big = fbm(uv, int2(2, 2), 3, sd + 8u);
    float3 c = P.colorA.rgb * (0.8 + 0.5 * mottle + 0.25 * big) * (0.94 + 0.12 * fine);
    c = mix(c, P.colorA.rgb * 0.62 + P.colorB.rgb * 0.15, patch * 0.55);
    // Pale silvery flecks and greenish algae film.
    c = mix(c, P.colorA.rgb * 1.25, smoothstep(0.15, 0.3, fbm(uv, int2(12, 6), 3, sd + 9u)) * 0.35);
    // Horizontal lenticel bands: short wavy dashes around the stem.
    float bandN = gnoise(uv * float2(6.0, 70.0), int2(6, 70), sd + 4u);
    float band = (1.0 - smoothstep(0.0, 0.08, abs(bandN))) * smoothstep(0.0, 0.3, fbm(uv, int2(10, 20), 2, sd + 5u)) * P.f.y;
    c = mix(c, P.colorB.rgb * 1.6, band * 0.35);
    // Eye scars: dark horizontal ellipses with a raised lip and short wings.
    float cid = 0.0, cid2 = 0.0;
    float2 off = cellLocal(uv, int2(3, 5), sd + 6u, cid, cid2);
    float eye = 0.0, lip = 0.0;
    if (cid < 0.4) {
        float2 e = off * float2(1.0, 2.4) / (0.18 + 0.12 * cid2);
        float r = length(e);
        eye = 1.0 - smoothstep(0.55, 0.75, r);
        lip = smoothstep(0.5, 0.75, r) * (1.0 - smoothstep(0.75, 1.1, r));
        float wing = (1.0 - smoothstep(0.0, 0.06, abs(off.y * 3.0 + abs(off.x) * 0.9 - 0.02))) * (1.0 - smoothstep(0.1, 0.45, abs(off.x)));
        eye = max(eye, wing * 0.6);
    }
    c = mix(c, P.colorB.rgb, eye * 0.85);
    float lichen = smoothstep(0.12, 0.35, fbm(uv, int2(3, 3), 5, sd + 7u) + fine * 0.3);
    c = mix(c, P.colorC.rgb * (0.85 + 0.3 * fine), lichen * P.f.x);
    s.albedo = c;
    s.height = 0.55 + mottle * 0.06 + fine * 0.05 - band * 0.04 - eye * 0.2 + lip * 0.1 + lichen * P.f.x * 0.05;
    s.rough = 0.62 + 0.15 * patch + 0.1 * eye;
    s.ao = 1.0 - eye * 0.45;
    return s;
}
// Quaking aspen: chalky white-green skin, black diamond scars below fallen branches, dark lenticel
// dashes and rough black patches. Knobs: x scar amount.
S barkAspen(float2 uv, constant RFParams &P) {
    S s = defaults(); uint sd = P.seed;
    float n = fbm(uv, int2(4, 4), 5, sd + 1u);
    float fine = fbm(uv, int2(40, 40), 3, sd + 2u);
    float3 c = P.colorA.rgb * (0.9 + 0.18 * n) * (0.96 + 0.08 * fine);
    c = mix(c, P.colorC.rgb, smoothstep(0.0, 0.4, fbm(uv, int2(3, 6), 4, sd + 3u)) * 0.5);   // greenish/orange tinge
    // Lenticels: short horizontal dark dashes.
    float4 lw = worley(uv, int2(7, 40), sd + 4u, 0.9);
    float lent = smoothstep(0.3, 0.12, lw.x) * step(0.82, lw.z);
    // Diamond eye scars.
    float cid = 0.0, cid2 = 0.0;
    float2 off = cellLocal(uv, int2(3, 4), sd + 5u, cid, cid2);
    float scar = 0.0;
    if (cid < P.f.x) {
        float sz = 0.2 + 0.15 * cid2;
        float dm = abs(off.x) / (sz * 1.3) + abs(off.y * 1.6) / sz;
        float rough = fbm(uv, int2(24, 24), 3, sd + 6u) * 0.35;
        scar = 1.0 - smoothstep(0.75, 0.95, dm + rough);
    }
    float blotch = smoothstep(0.32, 0.45, fbm(uv, int2(3, 4), 5, sd + 7u) + 0.2 * fine);
    float dark = max(scar, blotch * 0.8);
    c = mix(c, P.colorB.rgb * (0.8 + 0.4 * fine), max(dark, lent * 0.8));
    s.albedo = c;
    s.height = 0.6 + n * 0.08 + fine * 0.04 - lent * 0.15 - dark * (0.25 + 0.2 * fine);
    s.rough = mix(0.55, 0.92, max(dark, lent));
    s.ao = 1.0 - dark * 0.35;
    return s;
}
// Dead weathered wood: silver-grey checked grain along the stem, with remnant bark patches lifting at
// their edges. Knobs: x bark remaining (0...1).
S barkDead(float2 uv, constant RFParams &P) {
    S s = defaults(); uint sd = P.seed;
    float2 warp = float2(fbm(uv, int2(3, 2), 3, sd + 1u) * 0.05, 0.0);
    float2 q = uv + warp;
    float grain = fbm(q, int2(48, 3), 4, sd + 2u);
    float grain2 = fbm(q, int2(128, 6), 3, sd + 3u);
    float check = 1.0 - smoothstep(0.0, 0.035, abs(gnoise(q * float2(20.0, 2.0), int2(20, 2), sd + 4u)));
    check *= smoothstep(-0.05, 0.2, fbm(uv, int2(4, 6), 3, sd + 5u));
    float3 wood = P.colorA.rgb * (0.8 + 0.35 * grain + 0.12 * grain2);
    wood = mix(wood, P.colorA.rgb * 0.55 + float3(0.02, 0.015, 0.0), smoothstep(0.1, 0.4, fbm(uv, int2(3, 3), 4, sd + 6u)) * 0.4);
    wood = mix(wood, P.colorB.rgb * 0.6, check);
    // Remnant bark: patches above a noise threshold; edges curl up and show the paler inner bark.
    float bn = fbm(uv, int2(6, 2), 5, sd + 7u) + 0.15 * fbm(uv, int2(16, 8), 3, sd + 8u);
    float th = mix(0.3, -0.35, P.f.x);
    float bark = smoothstep(th, th + 0.03, bn);
    float edge = smoothstep(th, th + 0.03, bn) * (1.0 - smoothstep(th + 0.03, th + 0.09, bn));
    float4 w = worley(uv, int2(10, 4), sd + 9u, 0.9);
    float furrow = 1.0 - smoothstep(0.02, 0.2, w.y - w.x);
    float3 barkCol = mix(P.colorB.rgb * (0.85 + 0.3 * grain), P.colorB.rgb * 0.5, furrow);
    float3 c = mix(wood, barkCol, bark);
    c = mix(c, P.colorC.rgb, edge * 0.55);
    s.albedo = c;
    s.height = 0.45 + grain * 0.12 + grain2 * 0.05 - check * 0.3 + bark * (0.22 - furrow * 0.12) + edge * 0.1;
    s.rough = mix(0.8 + 0.1 * grain, 0.92, bark);
    s.ao = (1.0 - check * 0.6) * (1.0 - bark * furrow * 0.4) * (1.0 - smoothstep(th - 0.08, th, bn) * (1.0 - bark) * 0.35);
    return s;
}
"""#
