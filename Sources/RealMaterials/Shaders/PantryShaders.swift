// Pantry surfaces seen in vessels: powders, crystals, liquids, batters and melted fats.

let metalPantry = #"""
// Powder, crystal or glossy liquid surface. colorA base, colorB shade, colorC highlight.
// knobs: x grain cells per tile (powder clumps / sugar crystals), y crystal sparkle 0...1,
// z swirl (stirred liquid streaks) 0...1, w bubble amount (foam, batter bubbles) 0...1.
S pantryFill(float2 uv, constant RFParams &P) {
    S s = defaults(); uint sd = P.seed;
    int G = max(8, int(P.f.x));
    float und = fbm(uv, int2(3, 3), 4, sd + 1u);
    float clump = fbm(uv, int2(G / 4, G / 4), 3, sd + 2u);
    float4 w = worley(uv, int2(G, G), sd + 3u, 0.9);
    float facet = (w.y - w.x);
    float3 c = P.colorA.rgb * (0.94 + 0.12 * und + 0.06 * clump);
    c = mix(c, P.colorB.rgb, smoothstep(0.0, 0.25, 0.25 - facet) * P.f.y * 0.5);
    // Stirred streaks: long low-frequency bands warped by noise.
    float sw = sin((uv.x * 6.2831853 * 2.0) + fbm(uv, int2(2, 2), 3, sd + 4u) * 9.0);
    c = mix(c, P.colorC.rgb, smoothstep(0.6, 1.0, sw) * P.f.z * 0.4);
    // Bubbles: small round pits with bright rims.
    float bc = 0.0, bc2 = 0.0;
    float2 off = cellLocal(uv, int2(G / 2, G / 2), sd + 5u, bc, bc2);
    float bub = 0.0;
    if (bc < P.f.w) {
        float r = length(off) / (0.12 + 0.18 * bc2);
        if (r < 1.0) { bub = 1.0 - r; c = mix(c, P.colorB.rgb * 0.85, bub * 0.6); }
        else if (r < 1.25) { c = mix(c, P.colorC.rgb, (1.25 - r) * 2.0 * 0.5); }
    }
    s.albedo = c;
    s.height = 0.5 + und * 0.08 + clump * 0.06 + facet * P.f.y * 0.12 - bub * 0.1;
    s.rough = clamp(mix(0.92, 0.25, P.f.y) - 0.06 * clump, 0.03, 1.0);
    // Crystal sparkle: a few facets per cell turn mirror-like.
    if (P.f.y > 0.0 && w.z > 1.0 - 0.06 * P.f.y) { s.rough = 0.06; s.albedo *= 1.12; }
    s.ao = 1.0 - bub * 0.3;
    return s;
}
"""#
