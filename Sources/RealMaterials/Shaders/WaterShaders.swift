// Water programs: water.

let metalWater = #"""
// ---------------------------------------------------------------- water
// Wind ripples: a tileable height field (two directional wave trains plus fBm chop). The ShaderGraph
// water path scrolls two samples of the resulting normal map; albedo is the deep-water body color.
// colorA deep-water body color (colorB, the shallow color, is a ShaderGraph parameter), knobs.x chop 0...1.
S water(float2 uv, constant RFParams &P) {
    S s = defaults(); uint sd = P.seed;
    float chop = P.f.x > 0.0 ? P.f.x : 0.5;
    float w1 = sin((uv.x * 6.0 + uv.y * 2.0) * 6.2831853 + fbm(uv, int2(3, 3), 3, sd + 1u) * 4.0);
    float w2 = sin((uv.x * -3.0 + uv.y * 7.0) * 6.2831853 + fbm(uv, int2(4, 4), 3, sd + 2u) * 4.0);
    float n = fbm(uv, int2(8, 8), 4, sd + 3u);
    s.height = 0.5 + 0.05 * (w1 + w2) * (1.0 - chop * 0.5) + (n + 0.5 * fbm(uv, int2(5, 3), 4, sd + 4u)) * chop * 0.7;
    s.albedo = P.colorA.rgb * (0.95 + 0.1 * n);
    s.rough = 0.04 + 0.04 * sat(n + 0.5);
    s.ao = 1.0;
    return s;
}
"""#
