// RFParams, the S texel struct, tileable hash/noise helpers. Shared by every program.

let metalCommon = #"""
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
"""#
