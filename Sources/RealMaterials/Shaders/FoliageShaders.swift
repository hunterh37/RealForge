// Alpha atlas programs: leafBroad, leafNeedle, grassBlades. Draw content with v up the card.

let metalFoliage = #"""
// ---------------------------------------------------------------- foliage atlases (alpha)
// Broadleaf cluster: a twig with alternating leaves. Cell-local coords: (0,0) bottom-left, v up.
S leafBroad(float2 uv, constant RFParams &P) {
    S s = defaults(); s.alpha = 0.0; s.rough = 0.5;
    float g = P.f.z > 0.5 ? P.f.z : 2.0;
    float2 cuv = uv * g; int2 cell = int2(floor(cuv)); float2 p = cuv - floor(cuv);
    uint sd = P.seed + uint(cell.x * 7 + cell.y * 13);
    float lobed = P.f.x, autumn = P.f.y;
    // Twig: gentle curve from bottom center.
    float bend = (h01u(sd + 1u) - 0.5) * 0.25;
    float tw = abs(p.x - (0.5 + bend * p.y * p.y)) ;
    float twigTop = 0.78;
    float bestH = -1.0;
    float3 avgLeaf = mix(P.colorA.rgb, P.colorB.rgb, 0.5);
    s.albedo = avgLeaf;                               // bleed colour for transparent texels
    if (tw < 0.011 * (1.2 - p.y) && p.y < twigTop) {
        s.alpha = 1.0; s.albedo = float3(0.09, 0.06, 0.035); s.height = 0.35 - tw * 10.0; s.rough = 0.8; bestH = 0.3;
    }
    int count = 7 + int(h01u(sd + 2u) * 4.0);
    for (int i = 0; i < 11; i++) {
        if (i >= count) break;
        uint li = sd + 100u + uint(i) * 17u;
        float t = 0.06 + 0.70 * (float(i) + 0.5) / float(count);
        float side = (i % 2 == 0) ? 1.0 : -1.0;
        bool tip = (i == count - 1);
        float2 base = float2(0.5 + bend * t * t, t);
        float ang = tip ? (bend * 0.8) : side * (0.75 + 0.55 * h01u(li));   // radians from vertical
        float L = (tip ? 0.32 : 0.44) * (0.8 + 0.35 * h01u(li + 1u)) * (1.0 - 0.25 * t);
        float W = L * (lobed > 0.5 ? 0.66 : 0.5);
        float2 dir = float2(sin(ang), cos(ang));
        float2 nrm = float2(dir.y, -dir.x);
        float2 d = p - base;
        float x = dot(d, dir), y = dot(d, nrm);
        float pet = 0.06 * L;                       // petiole length
        float lx = (x - pet) / L;
        // petiole
        if (x > 0.0 && x < pet && abs(y) < 0.006 && 0.6 + float(i) * 0.05 > bestH) {
            bestH = 0.6 + float(i) * 0.05; s.alpha = 1.0; s.albedo = float3(0.08, 0.1, 0.03); s.height = 0.5; s.rough = 0.7;
        }
        if (lx <= 0.0 || lx >= 1.0) continue;
        float prof = pow(sin(3.14159 * pow(lx, 0.8)), 0.9) * (1.0 - 0.25 * lx);
        if (lobed > 0.5) {
            float lob = 0.62 + 0.38 * abs(cos(lx * 3.14159 * 4.5 + 0.3));
            prof *= lob;
        } else {
            prof *= 1.0 - 0.06 * abs(sin(lx * 120.0)) ;   // fine serration
        }
        float hw = W * 0.5 * prof;
        if (abs(y) > hw) continue;
        float hgt = 0.6 + float(i) * 0.05 + 0.1;
        if (hgt < bestH) continue;
        bestH = hgt;
        float yn = y / max(hw, 1e-4);
        float var = h01u(li + 3u);
        float3 c = mix(P.colorA.rgb, P.colorB.rgb, var);
        c *= 0.85 + 0.3 * fbm(p * 2.0, int2(6, 6), 3, li);
        // Autumn / sun-bleached tint per leaf.
        float yel = smoothstep(1.0 - autumn, 1.0, h01u(li + 4u));
        c = mix(c, P.colorC.rgb * (0.8 + 0.4 * var), yel);
        // Veins: midrib + angled secondaries.
        float mid = 1.0 - smoothstep(0.0, 0.05, abs(yn));
        float sec = 1.0 - smoothstep(0.0, 0.09, abs(fract(lx * 7.0 - abs(yn) * 0.9) - 0.5) * 2.0 - 0.0);
        sec *= smoothstep(0.95, 0.4, abs(yn)) * 0.6;
        float edgeDark = smoothstep(0.75, 1.0, abs(yn));
        c = mix(c, c * 1.35 + float3(0.02, 0.03, 0.0), max(mid, sec * 0.6));
        c *= 1.0 - 0.25 * edgeDark;
        // Tiny blemishes.
        float spot = smoothstep(0.62, 0.7, fbm(p, int2(20, 20), 2, li + 9u));
        c = mix(c, float3(0.12, 0.08, 0.03), spot * 0.6);
        s.albedo = c; s.alpha = 1.0;
        s.height = hgt + 0.25 * (1.0 - yn * yn) - mid * 0.08 - sec * 0.05;
        s.rough = 0.45 + 0.15 * var + spot * 0.2;
        s.ao = 0.75 + 0.25 * (1.0 - edgeDark * 0.5) - 0.2 * (1.0 - lx) * 0.5;
    }
    s.height = s.alpha > 0.5 ? s.height / 1.3 : 0.0;
    return s;
}

// Conifer sprig: twig + side shoots, dense needles at ~50 degrees.
float needleField(float2 p, float2 a, float2 b, float L, float thick, uint sd, thread float &along, thread float &tipness) {
    float2 ab = b - a; float len = length(ab); float2 t = ab / len; float2 n = float2(-t.y, t.x);
    float2 d = p - a; float s = dot(d, t), r = dot(d, n);
    if (s < -0.02 || s > len + L) return 0.0;
    float side = r >= 0.0 ? 1.0 : -1.0; float ar = abs(r);
    float ang = 0.85; float ta = tan(ang);
    float s0 = s - ar / ta;                            // where this needle leaves the twig
    float spacing = 0.0048;
    float k = floor(s0 / spacing + 0.5);
    float s1 = k * spacing;
    if (s1 < 0.0 || s1 > len) return 0.0;
    float jit = h01u(uint(int(k) * 2 + (side > 0.0 ? 1 : 0)) + sd);
    float nl = L * (0.75 + 0.35 * jit) * (0.55 + 0.45 * sin(3.14159 * clamp(s1 / len, 0.05, 1.0)));
    float dist = abs(s0 - s1) * sin(ang);
    float rr = ar / sin(ang);                           // distance along needle
    if (rr > nl) return 0.0;
    float w = thick * (1.0 - 0.7 * rr / nl);
    along = s1 / len; tipness = rr / nl;
    return dist < w ? 1.0 - dist / w : 0.0;
}
S leafNeedle(float2 uv, constant RFParams &P) {
    S s = defaults(); s.alpha = 0.0; s.rough = 0.55;
    float g = P.f.z > 0.5 ? P.f.z : 2.0;
    float2 cuv = uv * g; int2 cell = int2(floor(cuv)); float2 p = cuv - floor(cuv);
    uint sd = P.seed + uint(cell.x * 7 + cell.y * 13);
    s.albedo = P.colorA.rgb;
    float bend = (h01u(sd) - 0.5) * 0.15;
    float2 a = float2(0.5, 0.02), b = float2(0.5 + bend, 0.96);
    float best = 0.0; float along = 0.0, tipness = 0.0;
    float v = needleField(p, a, b, 0.095, 0.0055, sd, along, tipness);
    if (v > best) best = v;
    for (int i = 0; i < 8; i++) {
        float t = 0.08 + 0.105 * float(i);
        float side = (i % 2 == 0) ? 1.0 : -1.0;
        float2 o = mix(a, b, t);
        float reach = (0.40 - 0.03 * float(i)) * (0.85 + 0.3 * h01u(sd + uint(i) * 3u));
        float2 e = o + float2(side * reach * 0.8, reach * 0.6);
        float al2 = 0.0, tp2 = 0.0;
        float v2 = needleField(p, o, e, 0.075, 0.0048, sd + uint(i) * 31u, al2, tp2);
        if (v2 > best) { best = v2; along = al2; tipness = tp2; }
    }
    // twig itself
    float2 ab = b - a; float h = clamp(dot(p - a, ab) / dot(ab, ab), 0.0, 1.0);
    float tw = length(p - (a + ab * h));
    if (tw < 0.008) { s.alpha = 1.0; s.albedo = float3(0.11, 0.07, 0.04); s.height = 0.4; s.rough = 0.8; }
    if (best > 0.0) {
        s.alpha = 1.0;
        float3 c = mix(P.colorA.rgb, P.colorB.rgb, h01u(sd + uint(along * 300.0)));
        float fresh = smoothstep(0.78, 0.95, along) * P.f.x;          // light-green new growth at tips
        c = mix(c, P.colorC.rgb, fresh);
        c *= 0.75 + 0.35 * tipness;
        s.albedo = c; s.height = 0.5 + 0.5 * best; s.rough = 0.45 + 0.15 * tipness;
        s.ao = 0.6 + 0.4 * tipness;
    }
    return s;
}
// Grass clump card: tapered, curved blades rooted at the bottom edge.
S grassBlades(float2 uv, constant RFParams &P) {
    S s = defaults(); s.alpha = 0.0; s.albedo = P.colorA.rgb; s.rough = 0.6;
    float g = P.f.z > 0.5 ? P.f.z : 1.0;
    float2 cuv = uv * g; int2 cell = int2(floor(cuv)); float2 p = cuv - floor(cuv);
    uint sd = P.seed + uint(cell.x * 7 + cell.y * 13);
    float best = -1.0;
    for (int i = 0; i < 36; i++) {
        uint bi = sd + uint(i) * 23u;
        float x0 = 0.08 + 0.84 * h01u(bi);
        float hh = 0.45 + 0.53 * h01u(bi + 1u);
        float lean = (h01u(bi + 2u) - 0.5) * 0.5;
        float w0 = 0.010 + 0.014 * h01u(bi + 3u);
        if (p.y > hh) continue;
        float t = p.y / hh;
        float cx = x0 + lean * t * t * hh;
        float hw = w0 * (1.0 - pow(t, 1.6));
        float dx = abs(p.x - cx);
        if (dx > hw) continue;
        float depth = h01u(bi + 4u);
        if (depth < best) continue;
        best = depth;
        float dry = step(1.0 - P.f.x, h01u(bi + 5u));
        float3 c = mix(P.colorA.rgb, P.colorB.rgb, t * 0.8 + 0.2 * h01u(bi + 6u));
        c = mix(c, P.colorC.rgb * (0.8 + 0.4 * t), dry);
        float rib = 1.0 - dx / max(hw, 1e-4);
        s.albedo = c * (0.85 + 0.25 * rib); s.alpha = 1.0;
        s.height = 0.4 + 0.5 * rib; s.rough = 0.5 + 0.2 * dry;
        s.ao = mix(0.35, 1.0, smoothstep(0.0, 0.5, t)) * (0.85 + 0.15 * depth);
    }
    return s;
}
"""#
