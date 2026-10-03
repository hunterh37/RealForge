// Metal source compiled at runtime (device.makeLibrary(source:)), so the package builds with plain
// `swift build` and needs no .metallib resource step. Compiled once per process (~40 ms), then cached.

let realForgeMetalSource = #"""
#include <metal_stdlib>
using namespace metal;

struct RFParams {
    int kind; uint seed; int size; int alphaMode;
    float4 colorA; float4 colorB; float4 colorC;
    float4 f;          // material-specific knobs
    float normalStrength; float flipGreen; float pad0; float pad1;
};

struct S { float3 albedo; float alpha; float height; float rough; float ao; float metal; };

// ---------------------------------------------------------------- hashing / noise (all tileable)
inline uint pcg(uint v) { uint s = v * 747796405u + 2891336453u; uint w = ((s >> ((s >> 28u) + 4u)) ^ s) * 277803737u; return (w >> 22u) ^ w; }
inline uint hash2(int2 c, uint seed) { return pcg(uint(c.x) ^ pcg(uint(c.y) ^ pcg(seed))); }
inline float h01(int2 c, uint s) { return float(hash2(c, s) & 0xffffffu) / 16777216.0; }
inline float h01u(uint v) { return float(pcg(v) & 0xffffffu) / 16777216.0; }
inline int2 wrapc(int2 c, int2 per) { return ((c % per) + per) % per; }

inline float grad(int2 c, float2 d, int2 per, uint seed) {
    float a = h01(wrapc(c, per), seed) * 6.2831853;
    return dot(float2(cos(a), sin(a)), d);
}
// Periodic gradient noise, ~[-0.7, 0.7]. p in [0, per).
float gnoise(float2 p, int2 per, uint seed) {
    float2 fl = floor(p); int2 i = int2(fl); float2 f = p - fl;
    float2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
    float a = grad(i, f, per, seed), b = grad(i + int2(1, 0), f - float2(1, 0), per, seed);
    float c = grad(i + int2(0, 1), f - float2(0, 1), per, seed), d = grad(i + int2(1, 1), f - float2(1, 1), per, seed);
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}
// fBm of tileable noise: uv in [0,1), base frequency per axis (integers keep it periodic).
float fbm(float2 uv, int2 freq, int oct, uint seed) {
    float s = 0.0, amp = 0.5; int2 fr = freq;
    for (int o = 0; o < oct; o++) { s += amp * gnoise(uv * float2(fr), fr, seed + uint(o) * 101u); fr *= 2; amp *= 0.5; }
    return s;
}
float ridged(float2 uv, int2 freq, int oct, uint seed) {
    float s = 0.0, amp = 0.5, w = 1.0; int2 fr = freq;
    for (int o = 0; o < oct; o++) {
        float n = 1.0 - abs(gnoise(uv * float2(fr), fr, seed + uint(o) * 131u) * 1.4);
        n = n * n * w; w = clamp(n * 2.0, 0.0, 1.0);
        s += amp * n; fr *= 2; amp *= 0.5;
    }
    return s;
}
// Periodic Worley: x = F1, y = F2, z = hash of nearest cell, w = angle-ish second hash.
float4 worley(float2 uv, int2 freq, uint seed, float jitter) {
    float2 p = uv * float2(freq); float2 fl = floor(p); int2 c = int2(fl);
    float f1 = 9.0, f2 = 9.0; float id = 0.0, id2 = 0.0;
    for (int y = -1; y <= 1; y++) for (int x = -1; x <= 1; x++) {
        int2 cc = c + int2(x, y); int2 w = wrapc(cc, freq);
        float2 j = float2(h01(w, seed), h01(w, seed + 7u)) * jitter + (1.0 - jitter) * 0.5;
        float d = length(float2(cc) + j - p);
        if (d < f1) { f2 = f1; f1 = d; id = h01(w, seed + 13u); id2 = h01(w, seed + 29u); }
        else if (d < f2) { f2 = d; }
    }
    return float4(f1, f2, id, id2);
}
// Nearest cell center (offset vector from p) for cell-local shapes (leaf litter, stones).
float2 cellLocal(float2 uv, int2 freq, uint seed, thread float &cid, thread float &cid2) {
    float2 p = uv * float2(freq); float2 fl = floor(p); int2 c = int2(fl);
    float best = 9.0; float2 off = 0.0;
    for (int y = -1; y <= 1; y++) for (int x = -1; x <= 1; x++) {
        int2 cc = c + int2(x, y); int2 w = wrapc(cc, freq);
        float2 j = float2(h01(w, seed), h01(w, seed + 7u));
        float2 d = p - (float2(cc) + j);
        float l = dot(d, d);
        if (l < best) { best = l; off = d; cid = h01(w, seed + 13u); cid2 = h01(w, seed + 29u); }
    }
    return off;
}
inline float2 rot2(float2 p, float a) { float c = cos(a), s = sin(a); return float2(c * p.x - s * p.y, s * p.x + c * p.y); }
inline float sat(float x) { return clamp(x, 0.0, 1.0); }

S defaults() { S s; s.albedo = float3(0.5); s.alpha = 1.0; s.height = 0.5; s.rough = 0.8; s.ao = 1.0; s.metal = 0.0; return s; }

// ---------------------------------------------------------------- bark
S barkOak(float2 uv, constant RFParams &P) {
    S s = defaults(); uint sd = P.seed;
    // Furrows are zero-crossings of anisotropic noise: a meandering, mostly vertical crevice network
    // between broad plates (mature oak). Two scales: main furrows + finer splits.
    float2 warp = float2(fbm(uv, int2(3, 2), 4, sd + 1u), fbm(uv, int2(3, 3), 3, sd + 2u));
    float2 q = uv + warp * 0.04;
    float g1 = gnoise(q * float2(11, 3), int2(11, 3), sd + 3u) + 0.35 * gnoise(q * float2(22, 6), int2(22, 6), sd + 4u);
    float g2 = gnoise(q * float2(26, 5), int2(26, 5), sd + 5u);
    float fA = 1.0 - smoothstep(0.0, 0.16, abs(g1));
    float fB = (1.0 - smoothstep(0.0, 0.07, abs(g2))) * smoothstep(-0.1, 0.25, fbm(uv, int2(5, 3), 3, sd + 9u));
    float furrow = max(fA, fB * 0.55);
    float bulge = smoothstep(0.0, 0.5, abs(g1));
    float fib = fbm(uv, int2(64, 8), 4, sd + 6u);
    float fine = fbm(uv, int2(32, 32), 3, sd + 7u);
    float plate = 1.0 - furrow;
    s.height = plate * (0.55 + 0.25 * bulge) + fib * 0.1 + fine * 0.08;
    float3 top = P.colorA.rgb * (0.8 + 0.35 * fbm(uv, int2(8, 4), 3, sd + 10u)) * (0.9 + 0.25 * fine);
    float3 deep = P.colorB.rgb * (0.8 + 0.4 * fib);
    s.albedo = mix(deep, top, smoothstep(0.1, 0.75, plate * (0.6 + 0.4 * bulge)));
    float lichen = smoothstep(0.08, 0.3, fbm(uv, int2(3, 4), 5, sd + 11u) + fine * 0.35) * smoothstep(0.5, 0.9, plate);
    s.albedo = mix(s.albedo, P.colorC.rgb * (0.8 + 0.4 * fib), lichen * P.f.x);
    float moss = smoothstep(0.1, 0.35, fbm(uv, int2(2, 2), 4, sd + 12u)) * furrow * P.f.y;
    s.albedo = mix(s.albedo, float3(0.03, 0.055, 0.012), moss);
    s.rough = mix(0.97, 0.84, plate) - lichen * 0.05;
    s.ao = mix(0.25, 1.0, smoothstep(0.0, 0.6, s.height));
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

// ---------------------------------------------------------------- stone / ground
S rockGranite(float2 uv, constant RFParams &P) {
    S s = defaults(); uint sd = P.seed;
    float big = fbm(uv, int2(3, 3), 5, sd + 1u);
    float r = ridged(uv, int2(4, 4), 5, sd + 2u);
    float4 sp = worley(uv, int2(150, 150), sd + 3u, 0.9);
    float grain = smoothstep(0.6, 0.2, sp.x) * (0.5 + 0.5 * smoothstep(-0.2, 0.3, fbm(uv, int2(8, 8), 3, sd + 11u)));
    float3 base = mix(P.colorA.rgb, P.colorB.rgb, smoothstep(-0.3, 0.3, big));
    float3 mineral = sp.z < 0.18 ? float3(0.025, 0.025, 0.028) : (sp.z < 0.30 ? float3(0.62, 0.6, 0.58) : (sp.z < 0.38 ? P.colorC.rgb : base));
    s.albedo = mix(base, mineral, grain * 0.45) * (0.85 + 0.3 * fbm(uv, int2(24, 24), 3, sd + 4u));
    float4 cr = worley(uv + 0.03 * float2(fbm(uv, int2(5, 5), 3, sd + 5u), fbm(uv, int2(5, 5), 3, sd + 6u)), int2(5, 5), sd + 7u, 1.0);
    float crack = (1.0 - smoothstep(0.0, 0.02, cr.y - cr.x)) * smoothstep(0.1, 0.35, fbm(uv, int2(4, 4), 4, sd + 12u));
    float lich = smoothstep(0.25, 0.45, fbm(uv, int2(5, 5), 5, sd + 8u)) * P.f.x;
    float lspots = smoothstep(0.35, 0.2, worley(uv, int2(30, 30), sd + 9u, 1.0).x) * lich;
    s.albedo = mix(s.albedo, float3(0.36, 0.38, 0.27), lich * 0.65);
    s.albedo = mix(s.albedo, float3(0.42, 0.2, 0.05), lspots * 0.5);
    s.albedo *= 1.0 - crack * 0.6;
    s.height = 0.45 + big * 0.25 + r * 0.25 + grain * 0.04 - crack * 0.3 + lich * 0.03;
    s.rough = 0.78 - (sp.z > 0.18 && sp.z < 0.30 ? grain * 0.3 : 0.0) + lich * 0.1;
    s.ao = mix(0.5, 1.0, smoothstep(0.1, 0.7, s.height));
    return s;
}
S forestFloor(float2 uv, constant RFParams &P) {
    S s = defaults(); uint sd = P.seed;
    float n = fbm(uv, int2(6, 6), 5, sd + 1u);
    s.albedo = P.colorA.rgb * (0.75 + 0.5 * n);
    s.height = 0.3 + n * 0.2; s.rough = 0.92; s.ao = 0.8;
    // Leaf litter: three overlapping layers of oriented leaf shapes.
    for (int layer = 0; layer < 3; layer++) {
        float cid = 0.0, cid2 = 0.0;
        int fr = 14 + layer * 5;
        float2 off = cellLocal(uv + float2(0.37, 0.11) * float(layer), int2(fr, fr), sd + 10u + uint(layer) * 19u, cid, cid2);
        if (cid > P.f.y) continue;                                   // litter amount
        float2 q = rot2(off, cid2 * 6.2831853);
        float L = 0.42 + 0.25 * cid2;
        float lx = q.x / L;
        float prof = pow(max(0.0, 1.0 - lx * lx), 0.8) * (1.0 - 0.3 * lx) * 0.42 * L;
        if (abs(lx) < 1.0 && abs(q.y) < prof) {
            float yn = q.y / max(prof, 1e-4);
            float3 c = mix(P.colorB.rgb, P.colorC.rgb, cid2);
            c *= 0.8 + 0.4 * h01u(uint(cid * 1e6));
            float vein = 1.0 - smoothstep(0.0, 0.08, abs(yn));
            s.albedo = c * (1.0 + 0.2 * vein); s.height = 0.55 + 0.1 * float(layer) + 0.1 * (1.0 - yn * yn) - vein * 0.04;
            s.rough = 0.75; s.ao = 0.9;
        }
    }
    // Twigs.
    float4 tw = worley(uv, int2(7, 7), sd + 40u, 1.0);
    float2 tq = rot2(uv * 7.0, tw.z * 6.28);
    float twig = (1.0 - smoothstep(0.0, 0.025, abs(fract(tq.y) - 0.5) - 0.0)) * step(tw.x, 0.45) * step(0.75, tw.w);
    s.albedo = mix(s.albedo, float3(0.09, 0.06, 0.04), twig);
    s.height += twig * 0.25;
    // Moss / grass patches.
    float moss = smoothstep(0.0, 0.25, fbm(uv, int2(3, 3), 5, sd + 50u) + (P.f.x - 0.5) * 0.6);
    float mfine = fbm(uv, int2(64, 64), 3, sd + 51u);
    s.albedo = mix(s.albedo, float3(0.045, 0.075, 0.018) * (0.7 + 0.6 * mfine) + float3(0.02, 0.02, 0.0) * n, moss);
    s.height = mix(s.height, 0.62 + 0.15 * mfine, moss);
    s.rough = mix(s.rough, 0.95, moss);
    s.ao = mix(s.ao, 0.85 + 0.15 * mfine, moss);
    return s;
}

// ---------------------------------------------------------------- built world
S woodPlank(float2 uv, constant RFParams &P) {
    S s = defaults(); uint sd = P.seed;
    // Flat-sawn grain along U: thin dark latewood lines over lighter earlywood, gently wavy, with
    // occasional cathedral arches from the low-frequency warp.
    float warp = fbm(uv, int2(1, 2), 4, sd + 1u) * 1.6 + fbm(uv, int2(3, 6), 3, sd + 2u) * 0.25;
    float r = fract(uv.y * 22.0 + warp * 3.0);
    float late = smoothstep(0.0, 0.06, r) * (1.0 - smoothstep(0.06, 0.32, r));
    float streak = fbm(uv, int2(3, 128), 3, sd + 3u);
    float pores = smoothstep(0.35, 0.6, fbm(uv, int2(6, 256), 2, sd + 9u));
    float4 kw = worley(uv, int2(2, 3), sd + 4u, 0.8);
    float knotMask = step(0.78, kw.z);
    float knot = smoothstep(0.07, 0.0, kw.x) * knotMask;
    float knotRing = (0.5 + 0.5 * sin(kw.x * 180.0)) * smoothstep(0.18, 0.05, kw.x) * knotMask;
    float3 c = mix(P.colorA.rgb, P.colorB.rgb, sat(late * 0.75 + streak * 0.35 + 0.15));
    c *= 1.0 - pores * 0.08;
    c = mix(c, P.colorB.rgb * 0.45, max(knot, knotRing * 0.45));
    float weather = P.f.x;
    float3 grey = float3(0.30, 0.29, 0.27) * (0.85 + 0.35 * streak);
    c = mix(c, mix(grey, c * 0.8, late * 0.4), weather);
    s.albedo = c;
    s.height = 0.5 - late * 0.05 * (1.0 + weather * 5.0) + streak * 0.06 * (1.0 + weather * 3.0) - knot * 0.1 - pores * 0.03;
    s.rough = mix(P.f.y, 0.9, weather) + late * 0.04;
    s.ao = 1.0 - late * 0.2 * weather;
    return s;
}
S paintedMetal(float2 uv, constant RFParams &P) {
    S s = defaults(); uint sd = P.seed;
    float peel = fbm(uv, int2(48, 48), 3, sd + 1u);                 // orange peel
    float wear = fbm(uv, int2(5, 5), 5, sd + 2u);
    float chip = smoothstep(0.24, 0.27, wear * 1.6 + 0.15 * fbm(uv, int2(40, 40), 2, sd + 3u) - (1.0 - P.f.x) * 0.3);
    float scratch = 0.0;
    for (int i = 0; i < 3; i++) {
        float a = h01u(sd + uint(i) * 11u) * 3.14159;
        int2 fr = int2(4 * (i + 1), 160);
        float2 r = rot2(uv - 0.5, a) + 0.5;
        float sn = gnoise(fract(r) * float2(fr), fr, sd + 20u + uint(i));
        scratch = max(scratch, (1.0 - smoothstep(0.0, 0.02, abs(sn))) * smoothstep(0.2, 0.5, fbm(uv, int2(3, 3), 3, sd + 30u + uint(i))));
    }
    scratch *= P.f.x;
    float dirt = smoothstep(-0.1, 0.4, fbm(uv, int2(3, 3), 5, sd + 4u)) * P.f.y;
    float3 paint = P.colorA.rgb * (0.95 + 0.1 * peel);
    float3 bare = float3(0.56, 0.55, 0.53);
    float3 primer = P.colorC.rgb;
    s.albedo = mix(paint, primer, chip);
    s.albedo = mix(s.albedo, bare, scratch * 0.8);
    s.albedo = mix(s.albedo, s.albedo * float3(0.45, 0.4, 0.33), dirt * 0.6);
    s.metal = max(scratch * 0.9, chip * P.colorC.a);
    s.rough = mix(P.f.z, 0.35, scratch) + dirt * 0.25 + chip * 0.3;
    s.height = 0.6 + peel * 0.02 - chip * 0.25 - scratch * 0.1;
    s.ao = 1.0 - dirt * 0.2;
    return s;
}
S rustMetal(float2 uv, constant RFParams &P) {
    S s = defaults(); uint sd = P.seed;
    float n = fbm(uv, int2(4, 4), 6, sd + 1u);
    float pits = smoothstep(0.25, 0.05, worley(uv, int2(40, 40), sd + 2u, 1.0).x) * 0.6;
    float bare = smoothstep(0.1, 0.25, -n - (1.0 - P.f.x) * 0.3);
    float3 rust = mix(P.colorA.rgb, P.colorB.rgb, smoothstep(-0.3, 0.4, fbm(uv, int2(12, 12), 4, sd + 3u)));
    s.albedo = mix(rust, float3(0.5, 0.49, 0.47), bare) * (1.0 - pits * 0.5);
    s.metal = bare; s.rough = mix(0.88, 0.45, bare);
    s.height = 0.5 + n * 0.3 - pits * 0.3; s.ao = 1.0 - pits * 0.4;
    return s;
}
S concrete(float2 uv, constant RFParams &P) {
    S s = defaults(); uint sd = P.seed;
    float n = fbm(uv, int2(4, 4), 6, sd + 1u);
    float4 ag = worley(uv, int2(55, 55), sd + 2u, 1.0);
    float stone = smoothstep(0.4, 0.3, ag.x) * step(0.6, ag.z);
    float4 pw = worley(uv, int2(90, 90), sd + 3u, 1.0);
    float pore = smoothstep(0.12, 0.05, pw.x) * step(0.75, pw.z);
    float stain = smoothstep(0.0, 0.5, fbm(uv, int2(2, 2), 5, sd + 4u)) * P.f.y;
    float3 c = P.colorA.rgb * (0.85 + 0.3 * n);
    c = mix(c, P.colorB.rgb * (0.8 + 0.5 * ag.w), stone * 0.6);
    c *= 1.0 - pore * 0.6;
    c = mix(c, c * float3(0.6, 0.58, 0.52), stain);
    s.albedo = c; s.height = 0.5 + n * 0.15 + stone * 0.05 - pore * 0.4;
    s.rough = P.f.x + 0.08 * n + stain * 0.05; s.ao = 1.0 - pore * 0.5;
    return s;
}
S asphalt(float2 uv, constant RFParams &P) {
    S s = defaults(); uint sd = P.seed;
    float4 ag = worley(uv, int2(80, 80), sd + 1u, 1.0);
    float stone = smoothstep(0.5, 0.25, ag.x);
    float n = fbm(uv, int2(6, 6), 5, sd + 2u);
    float3 c = mix(P.colorA.rgb, P.colorB.rgb * (0.6 + 0.8 * ag.z), stone * step(0.35, ag.w));
    float4 cr = worley(uv, int2(3, 3), sd + 3u, 1.0);
    float crack = (1.0 - smoothstep(0.0, 0.012, cr.y - cr.x)) * smoothstep(0.2, 0.4, n + P.f.x * 0.3);
    s.albedo = c * (0.85 + 0.3 * n) * (1.0 - crack * 0.7);
    s.height = 0.5 + stone * 0.3 - (1.0 - stone) * 0.1 - crack * 0.5;
    s.rough = 0.88 - stone * 0.1; s.ao = mix(0.7, 1.0, stone) * (1.0 - crack * 0.5);
    return s;
}
S plastic(float2 uv, constant RFParams &P) {
    S s = defaults(); uint sd = P.seed;
    float n = fbm(uv, int2(8, 8), 4, sd + 1u);
    float sc = 0.0;
    for (int i = 0; i < 2; i++) {
        float a = h01u(sd + uint(i) * 5u) * 3.14159; int2 fr = int2(6, 120);
        float2 r = rot2(uv - 0.5, a) + 0.5;
        sc = max(sc, (1.0 - smoothstep(0.0, 0.03, abs(gnoise(fract(r) * float2(fr), fr, sd + 9u + uint(i))))) * smoothstep(0.1, 0.4, fbm(uv, int2(3, 3), 3, sd + 20u)));
    }
    float dirt = smoothstep(0.0, 0.5, fbm(uv, int2(3, 3), 5, sd + 3u)) * P.f.y;
    s.albedo = P.colorA.rgb * (0.95 + 0.08 * n) * (1.0 - sc * 0.15 * P.f.x);
    s.albedo = mix(s.albedo, s.albedo * float3(0.5, 0.45, 0.4), dirt * 0.5);
    s.rough = P.f.z + sc * 0.25 * P.f.x + dirt * 0.2 + n * 0.03;
    s.height = 0.5 + n * 0.02 - sc * 0.1 * P.f.x; s.ao = 1.0 - dirt * 0.15;
    return s;
}
S brick(float2 uv, constant RFParams &P) {
    S s = defaults(); uint sd = P.seed;
    // 4 courses x 2 bricks per tile, running bond.
    float2 g = uv * float2(2.0, 4.0);
    float row = floor(g.y); g.x += fmod(row, 2.0) * 0.5;
    float2 cell = floor(g); float2 f = fract(g);
    float2 mort = float2(0.035, 0.07);
    float2 e = min(f, 1.0 - f) / mort;
    float inBrick = smoothstep(0.6, 1.4, min(e.x, e.y));
    float id = h01(int2(fmod(cell.x + 2.0, 2.0), fmod(cell.y + 4.0, 4.0)), sd);
    float n = fbm(uv, int2(16, 16), 4, sd + 1u);
    float3 bc = mix(P.colorA.rgb, P.colorB.rgb, id) * (0.85 + 0.3 * n);
    float3 mc = P.colorC.rgb * (0.9 + 0.2 * fbm(uv, int2(40, 40), 3, sd + 2u));
    s.albedo = mix(mc, bc, inBrick);
    s.height = mix(0.2 + 0.1 * n, 0.7 + 0.1 * n - 0.15 * pow(1.0 - inBrick, 2.0), inBrick);
    s.rough = mix(0.95, 0.85, inBrick); s.ao = mix(0.55, 1.0, inBrick);
    return s;
}

S evaluate(float2 uv, constant RFParams &P) {
    switch (P.kind) {
        case 0: return barkOak(uv, P);
        case 1: return barkBirch(uv, P);
        case 2: return barkPine(uv, P);
        case 3: return leafBroad(uv, P);
        case 4: return leafNeedle(uv, P);
        case 5: return grassBlades(uv, P);
        case 6: return rockGranite(uv, P);
        case 7: return forestFloor(uv, P);
        case 8: return woodPlank(uv, P);
        case 9: return paintedMetal(uv, P);
        case 10: return rustMetal(uv, P);
        case 11: return concrete(uv, P);
        case 12: return asphalt(uv, P);
        case 13: return plastic(uv, P);
        case 14: return brick(uv, P);
        default: return defaults();
    }
}

// ---------------------------------------------------------------- kernels
// Pixel (x, y) maps to uv = ((x+.5)/N, (y+.5)/N): RealityKit samples LowLevelTextures with v = 0 at row 0.
kernel void rf_material(texture2d<float, access::write> albedo [[texture(0)]],
                        texture2d<float, access::write> height [[texture(1)]],
                        texture2d<float, access::write> rough [[texture(2)]],
                        texture2d<float, access::write> ao [[texture(3)]],
                        texture2d<float, access::write> metal [[texture(4)]],
                        constant RFParams &P [[buffer(0)]],
                        uint2 gid [[thread_position_in_grid]]) {
    if (int(gid.x) >= P.size || int(gid.y) >= P.size) return;
    float2 uv = float2((float(gid.x) + 0.5) / float(P.size), (float(gid.y) + 0.5) / float(P.size));
    S s = evaluate(uv, P);
    float a = P.alphaMode == 1 ? s.alpha : 1.0;
    albedo.write(float4(clamp(s.albedo, 0.0, 1.0), a), gid);
    height.write(float4(s.height), gid);
    rough.write(float4(clamp(s.rough, 0.02, 1.0)), gid);
    ao.write(float4(clamp(s.ao, 0.0, 1.0)), gid);
    metal.write(float4(clamp(s.metal, 0.0, 1.0)), gid);
}

// Height -> tangent-space normal (wrapping Sobel). Output in [0,1] encoding, +Y = +V (bitangent).
kernel void rf_normal(texture2d<float, access::read> height [[texture(0)]],
                      texture2d<float, access::write> normal [[texture(1)]],
                      constant RFParams &P [[buffer(0)]],
                      uint2 gid [[thread_position_in_grid]]) {
    int N = P.size; if (int(gid.x) >= N || int(gid.y) >= N) return;
    int2 c = int2(gid);
    #define H(dx, dy) height.read(uint2((c + int2(dx, dy) + N) % N)).r
    float tl = H(-1, -1), t = H(0, -1), tr = H(1, -1), l = H(-1, 0), r = H(1, 0), bl = H(-1, 1), b = H(0, 1), br = H(1, 1);
    #undef H
    float dx = (tr + 2.0 * r + br) - (tl + 2.0 * l + bl);
    float dy = (bl + 2.0 * b + br) - (tl + 2.0 * t + tr);   // +y pixel = +v
    float k = P.normalStrength * float(N) / 1024.0;
    float3 n = normalize(float3(-dx * k, -dy * k * P.flipGreen, 1.0));
    normal.write(float4(n * 0.5 + 0.5, 1.0), gid);
}

// Alpha mips with preserved alpha-test coverage (Castano 2010): downsample, count coverage for 16
// candidate scales, pick the scale whose coverage best matches mip 0, apply. All on the GPU.
kernel void rf_alpha_down(texture2d<float, access::read> src [[texture(0)]],
                          texture2d<float, access::write> dst [[texture(1)]],
                          uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= dst.get_width() || gid.y >= dst.get_height()) return;
    uint2 s = gid * 2;
    float4 a = src.read(s), b = src.read(s + uint2(1, 0)), c = src.read(s + uint2(0, 1)), d = src.read(s + uint2(1, 1));
    float wsum = a.a + b.a + c.a + d.a;
    float3 col = wsum > 0.0 ? (a.rgb * a.a + b.rgb * b.a + c.rgb * c.a + d.rgb * d.a) / wsum : (a.rgb + b.rgb + c.rgb + d.rgb) * 0.25;
    dst.write(float4(col, wsum * 0.25), gid);
}
constant float kScales[16] = { 1.0, 1.1, 1.2, 1.3, 1.4, 1.5, 1.65, 1.8, 2.0, 2.25, 2.5, 2.8, 3.2, 3.7, 4.3, 5.0 };
kernel void rf_alpha_count(texture2d<float, access::read> tex [[texture(0)]],
                           device atomic_uint *counts [[buffer(0)]],
                           uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= tex.get_width() || gid.y >= tex.get_height()) return;
    float a = tex.read(gid).a;
    for (int i = 0; i < 16; i++) if (a * kScales[i] > 0.5) atomic_fetch_add_explicit(&counts[i], 1u, memory_order_relaxed);
}
kernel void rf_alpha_apply(texture2d<float, access::read_write> tex [[texture(0)]],
                           device const uint *base [[buffer(0)]],      // level-0 counts
                           device const uint *counts [[buffer(1)]],    // this level's counts
                           uint2 gid [[thread_position_in_grid]]) {
    uint w = tex.get_width(), h = tex.get_height();
    if (gid.x >= w || gid.y >= h) return;
    float target = float(base[0]) / float(base[16]);           // base[16] = level-0 texel count
    float n = float(w * h);
    int best = 0; float err = 2.0;
    for (int i = 0; i < 16; i++) { float e = abs(float(counts[i]) / n - target); if (e < err) { err = e; best = i; } }
    float4 v = tex.read(gid);
    tex.write(float4(v.rgb, clamp(v.a * kScales[best], 0.0, 1.0)), gid);
}

// ---------------------------------------------------------------- sky
// Single-scattering atmosphere (Rayleigh + Mie, Nishita-style ray march) into an equirect HDR map.
struct SkyParams { float3 sunDir; float sunIntensity; float turbidity; float groundAlbedo; int width; int height; int drawSun; float exposure; float pad0; float pad1; };

float2 raySphere(float3 ro, float3 rd, float R) {
    float b = dot(ro, rd), c = dot(ro, ro) - R * R, d = b * b - c;
    if (d < 0.0) return float2(1e9, -1e9);
    d = sqrt(d); return float2(-b - d, -b + d);
}
float3 atmosphere(float3 rd, float3 sunDir, float turb, float sunI) {
    const float Re = 6360e3, Ra = 6420e3, Hr = 7994.0, Hm = 1200.0;
    const float3 betaR = float3(5.8e-6, 13.5e-6, 33.1e-6);
    float3 betaM = float3(21e-6) * turb;
    float3 ro = float3(0, Re + 2.0, 0);
    float2 t = raySphere(ro, rd, Ra);
    float tmax = t.y;
    float2 tg = raySphere(ro, rd, Re);
    if (tg.x > 0.0) tmax = min(tmax, tg.x);
    const int NS = 16, NL = 6;
    float seg = tmax / float(NS), tc = 0.0;
    float3 sumR = 0.0, sumM = 0.0; float odR = 0.0, odM = 0.0;
    float mu = dot(rd, sunDir);
    float phR = 3.0 / (16.0 * 3.14159) * (1.0 + mu * mu);
    float g = 0.76;
    float phM = 3.0 / (8.0 * 3.14159) * ((1.0 - g * g) * (1.0 + mu * mu)) / ((2.0 + g * g) * pow(1.0 + g * g - 2.0 * g * mu, 1.5));
    for (int i = 0; i < NS; i++) {
        float3 p = ro + rd * (tc + seg * 0.5);
        float h = length(p) - Re;
        float hr = exp(-h / Hr) * seg, hm = exp(-h / Hm) * seg;
        odR += hr; odM += hm;
        float2 tl = raySphere(p, sunDir, Ra);
        float segL = tl.y / float(NL), tcl = 0.0, odRL = 0.0, odML = 0.0; bool ok = true;
        for (int j = 0; j < NL; j++) {
            float3 pl = p + sunDir * (tcl + segL * 0.5);
            float hl = length(pl) - Re;
            if (hl < 0.0) { ok = false; break; }
            odRL += exp(-hl / Hr) * segL; odML += exp(-hl / Hm) * segL; tcl += segL;
        }
        if (ok) {
            const float3 betaO = float3(0.65e-6, 1.881e-6, 0.085e-6) * 2.0;   // ozone: keeps horizons blue, not green
            float3 tau = (betaR + betaO) * (odR + odRL) + betaM * 1.1 * (odM + odML);
            float3 att = exp(-tau);
            sumR += att * hr; sumM += att * hm;
        }
        tc += seg;
    }
    return sunI * (sumR * betaR * phR + sumM * betaM * phM);
}
kernel void rf_sky(texture2d<float, access::write> out [[texture(0)]],
                   constant SkyParams &S [[buffer(0)]],
                   uint2 gid [[thread_position_in_grid]]) {
    if (int(gid.x) >= S.width || int(gid.y) >= S.height) return;
    float u = (float(gid.x) + 0.5) / float(S.width), v = (float(gid.y) + 0.5) / float(S.height);
    float phi = (u - 0.5) * 2.0 * 3.14159265, theta = (0.5 - v) * 3.14159265;   // theta: elevation
    // Equirect convention: u=0.5 looks down -Z, +X at u=0.75.
    float3 rd = float3(sin(phi) * cos(theta), sin(theta), -cos(phi) * cos(theta));
    float3 sd = normalize(S.sunDir);
    float3 col;
    if (rd.y >= 0.0) {
        col = atmosphere(normalize(float3(rd.x, max(rd.y, 0.002), rd.z)), sd, S.turbidity, S.sunIntensity);
        if (S.drawSun == 1) {
            float cosA = dot(rd, sd);
            float disk = smoothstep(0.99996, 0.999985, cosA);
            float3 trans = exp(-(float3(5.8e-6, 13.5e-6, 33.1e-6) * 7994.0 + 21e-6 * S.turbidity * 1200.0) / max(sd.y, 0.03));
            col += disk * trans * S.sunIntensity * 40.0;
        }
    } else {
        // Ground: lit by sun + sky dome; fades into a horizon haze.
        float3 horizon = atmosphere(normalize(float3(rd.x, 0.002, rd.z)), sd, S.turbidity, S.sunIntensity);
        float sunH = max(sd.y, 0.0);
        float3 skyAmb = atmosphere(float3(0, 1, 0), sd, S.turbidity, S.sunIntensity);
        float3 groundCol = float3(0.16, 0.17, 0.12) * S.groundAlbedo * (skyAmb * 3.0 + float3(1.0, 0.95, 0.85) * sunH * S.sunIntensity * 0.06);
        col = mix(horizon, groundCol, smoothstep(0.0, 0.25, -rd.y));
    }
    col *= S.exposure;
    out.write(float4(col, 1.0), gid);
}
"""#
