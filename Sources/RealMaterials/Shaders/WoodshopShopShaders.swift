// Woodshop wall programs: perforated tempered hardboard (pegboard).

let metalWoodshopShop = #"""
// ---------------------------------------------------------------- woodshop shop wall
// Tempered hardboard pegboard: smooth brown face with faint fibre mottling and a satin sheen, holes on
// a square grid (dark bore with a softened rim and a height dip, so normals ring each hole). Hole
// centres sit at (k + 0.5) / N, so a sheet mapped from its corner in meters starts half a pitch in.
// colorA face, colorB fibre mottle, colorC hole bore. f.x holes per tile (integer; 12 for 1 in on a
// 0.3048 m tile), f.y hole radius as a fraction of the pitch (0.125 = 1/4 in holes at 1 in), f.z face
// roughness, f.w grime around the holes (hook wear).
S pegboard(float2 uv, constant RFParams &P) {
    S s = defaults(); uint sd = P.seed;
    float N = max(1.0, floor(P.f.x + 0.5));
    float r = clamp(P.f.y, 0.03, 0.45);
    float2 g = uv * N; float2 cell = floor(g); float2 f = g - cell - 0.5;
    float d = length(f);
    // Rim: punched holes have a slightly crushed, rounded lip about 0.4 of a radius wide.
    float rim = r * 0.4;
    float hole = 1.0 - smoothstep(r - 0.012, r + 0.004, d);
    float lip = smoothstep(r + rim, r, d) * (1.0 - hole);
    // Face: fine fibre mottling (pressed wood fibres), larger soft blotches, faint press-plate texture.
    float fine = fbm(uv, int2(96, 96), 3, sd + 1u);
    float blot = fbm(uv, int2(6, 6), 4, sd + 2u);
    float plate = gnoise(uv * 240.0, int2(240, 240), sd + 3u);
    float3 face = mix(P.colorA.rgb, P.colorB.rgb, sat(0.45 + 0.9 * blot + 0.5 * fine));
    face *= 0.96 + 0.06 * plate;
    // Hand grime: darker halo around some holes (hooks pulled in and out), per-hole random.
    float used = h01(wrapc(int2(cell), int2(int(N), int(N))), sd + 9u);
    float grime = P.f.w * smoothstep(r * 2.6, r, d) * smoothstep(0.55, 0.95, used + 0.25 * blot);
    face *= 1.0 - 0.28 * grime;
    float3 lipCol = face * 0.82;
    // Bore: dark cavity, a little brighter toward the rim where fibres catch light.
    float3 bore = P.colorC.rgb * (0.6 + 0.6 * smoothstep(r * 0.2, r, d));
    s.albedo = mix(mix(face, lipCol, lip), bore, hole);
    s.height = 0.62 + 0.012 * fine + 0.004 * plate - 0.1 * lip * lip - 0.55 * hole;
    s.rough = clamp(mix(P.f.z + 0.08 * fine + 0.12 * grime, 0.92, max(hole, lip * 0.6)), 0.2, 1.0);
    s.ao = mix(1.0, 0.25, hole) * (1.0 - 0.15 * lip);
    s.metal = 0.0;
    return s;
}
"""#
