// Compute kernels: material evaluation, Sobel normals, coverage-preserving alpha mips.

let metalKernels = #"""
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
"""#
