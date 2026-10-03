import simd

/// Smooth, UV-mapped primitives. UVs are in meters so every material keeps a constant texel density;
/// the material's tile size (RealMaterials) converts meters to texture repeats.
public enum Prim {

    /// Box with rounded edges of `radius`, centered at origin. Bevels catch highlights, which is most of
    /// what separates a real-looking prop from a CG cube. Per-face planar UVs in meters.
    public static func roundedBox(_ size: V3, radius: Float, bevelSegments: Int = 3, material: MaterialKey) -> Surface {
        let h = size / 2, r = min(radius, h.min() * 0.999)
        let inner = h - V3(repeating: r)
        var s = Surface(material: material)
        // Axis samples: dense in the bevel band, a single span across the flat part.
        func samples(_ half: Float) -> [Float] {
            var a: [Float] = []
            let seg = max(1, bevelSegments)
            for k in 0...seg { a.append(-half + r * Float(k) / Float(seg)) }
            if half - r > -half + r + 1e-5 {
                for k in 0...seg { a.append(half - r + r * Float(k) / Float(seg)) }
            } else { a.append(half) }
            return a
        }
        let sx = samples(h.x), sy = samples(h.y), sz = samples(h.z)
        // Each face: axis index, sign, and the two in-plane axes (u, v) with orientation chosen CCW-outward.
        let faces: [(Int, Float, Int, Int)] = [(0, 1, 2, 1), (0, -1, 2, 1), (1, 1, 0, 2), (1, -1, 0, 2), (2, 1, 0, 1), (2, -1, 0, 1)]
        let axisSamples = [sx, sy, sz]
        for (ax, sign, ua, va) in faces {
            let us = axisSamples[ua], vs = axisSamples[va]
            let base = UInt32(s.positions.count)
            for v in vs { for u in us {
                var p = V3.zero
                p[ax] = sign * h[ax]; p[ua] = u; p[va] = v
                let c = simd_clamp(p, -inner, inner)
                let d = p - c
                let n = simd_length(d) > 1e-7 ? simd_normalize(d) : V3.zero
                let q = c + n * r
                var uv = V2(q[ua], q[va])
                // Mirror U on negative faces so text-like textures read the right way round.
                if sign < 0 { uv.x = -uv.x }
                s.add(q, n == .zero ? { var f = V3.zero; f[ax] = sign; return f }() : n, uv)
            }}
            let nu = us.count
            for j in 0..<(vs.count - 1) { for i in 0..<(nu - 1) {
                let a = base + UInt32(j * nu + i), b = a + 1, c = a + UInt32(nu) + 1, d = a + UInt32(nu)
                // Orientation: cross(u, v) must point along +sign*axis.
                var cu = V3.zero, cv = V3.zero; cu[ua] = 1; cv[va] = 1
                let outward = simd_dot(simd_cross(cu, cv), { var f = V3.zero; f[ax] = sign; return f }()) > 0
                if outward { s.quad(a, b, c, d) } else { s.quad(a, d, c, b) }
            }}
        }
        s.recomputeNormals()
        s.computeTangents()
        return s
    }

    /// Surface of revolution around +Y. `profile` is (radius, y) from bottom to top. Closed ends happen
    /// when the profile starts/ends at radius 0. `seamTile` quantizes U so tiling textures wrap cleanly.
    public static func lathe(_ profile: [V2], segments: Int = 32, seamTile: Float = 0.25, material: MaterialKey, swapUV: Bool = false) -> Surface {
        var s = Surface(material: material)
        let maxR = profile.map(\.x).max() ?? 0.1
        // Small parts: true circumference (a seam is invisible at that size); larger ones quantize so tiles wrap.
        let circ = 2 * .pi * maxR
        let uTotal = circ < seamTile * 0.75 ? circ : max(seamTile, (circ / seamTile).rounded() * seamTile)
        var vAcc: [Float] = [0]
        for i in 1..<profile.count { vAcc.append(vAcc[i - 1] + simd_distance(profile[i], profile[i - 1])) }
        for (i, pr) in profile.enumerated() {
            for k in 0...segments {
                let t = Float(k) / Float(segments), a = t * 2 * .pi
                let uv = V2(t * uTotal, vAcc[i])
                s.add(V3(pr.x * cos(a), pr.y, -pr.x * sin(a)), .up, swapUV ? V2(uv.y, uv.x) : uv)
            }
        }
        let row = UInt32(segments + 1)
        for i in 0..<(profile.count - 1) { for k in 0..<segments {
            let a = UInt32(i) * row + UInt32(k)
            s.quad(a, a + 1, a + row + 1, a + row)
        }}
        s.recomputeNormals()
        s.computeTangents()
        return s
    }

    /// Generalized cylinder along `path` with per-point radius, parallel-transport frames (no twist
    /// flips), U quantized to `seamTile` around, V = arc length. `weights` (0..1) go to `extra.x`.
    public static func tube(_ path: [V3], radii: [Float], sides: Int, seamTile: Float, material: MaterialKey,
                            weights: [Float]? = nil, phase: Float = 0, capEnd: Bool = true, rippling: ((Float, Float) -> Float)? = nil) -> Surface {
        precondition(path.count >= 2 && radii.count == path.count)
        var s = Surface(material: material)
        let circ = 2 * .pi * radii[0]
        let uTotal = circ < seamTile * 0.75 ? circ : max(seamTile, (circ / seamTile).rounded() * seamTile)
        var tangents: [V3] = []
        for i in path.indices {
            let a = path[max(0, i - 1)], b = path[min(path.count - 1, i + 1)]
            tangents.append((b - a).normalized)
        }
        var normal = tangents[0].anyPerpendicular
        var v: Float = 0
        for i in path.indices {
            if i > 0 {
                v += simd_distance(path[i], path[i - 1])
                // Parallel transport: rotate previous normal by the rotation between successive tangents.
                let t0 = tangents[i - 1], t1 = tangents[i]
                let axis = simd_cross(t0, t1), sl = simd_length(axis)
                if sl > 1e-6 { normal = simd_quatf(angle: atan2(sl, simd_dot(t0, t1)), axis: axis / sl).act(normal) }
                normal = simd_normalize(normal - t1 * simd_dot(normal, t1))
            }
            let bin = simd_cross(tangents[i], normal)
            let w = weights?[i] ?? 0
            for k in 0...sides {
                let t = Float(k) / Float(sides), a = t * 2 * .pi
                let dir = normal * cos(a) + bin * sin(a)
                let r = radii[i] * (rippling?(t, v) ?? 1)
                s.add(path[i] + dir * r, dir, V2(t * uTotal, v), extra: V2(w, phase))
            }
        }
        let row = UInt32(sides + 1)
        for i in 0..<(path.count - 1) { for k in 0..<sides {
            let a = UInt32(i) * row + UInt32(k)
            s.quad(a, a + 1, a + row + 1, a + row)
        }}
        if capEnd {
            let tip = s.add(path[path.count - 1] + tangents[path.count - 1] * radii[radii.count - 1] * 0.5, tangents[path.count - 1],
                            V2(uTotal / 2, v + radii[radii.count - 1]), extra: V2(weights?.last ?? 0, phase))
            let last = UInt32(path.count - 1) * row
            for k in 0..<UInt32(sides) { s.tri(last + k, last + k + 1, tip) }
        }
        return s
    }

    /// Cube-sphere: six subdivided cube faces projected to a sphere. Per-face UVs (meters) avoid the
    /// pole pinching of UV spheres. `displace(dir) -> radius` shapes rocks/boulders.
    public static func cubeSphere(subdivisions n: Int, material: MaterialKey, radius: (V3) -> V3) -> Surface {
        var s = Surface(material: material)
        let faces: [(V3, V3, V3)] = [
            (V3(1, 0, 0), V3(0, 0, -1), V3(0, 1, 0)), (V3(-1, 0, 0), V3(0, 0, 1), V3(0, 1, 0)),
            (V3(0, 1, 0), V3(1, 0, 0), V3(0, 0, -1)), (V3(0, -1, 0), V3(1, 0, 0), V3(0, 0, 1)),
            (V3(0, 0, 1), V3(1, 0, 0), V3(0, 1, 0)), (V3(0, 0, -1), V3(-1, 0, 0), V3(0, 1, 0)),
        ]
        for (nrm, u, v) in faces {
            let base = UInt32(s.positions.count)
            for j in 0...n { for i in 0...n {
                // Tangent-warped grid gives near-uniform cell area on the sphere.
                let a = tan((Float(i) / Float(n) * 2 - 1) * .pi / 4), b = tan((Float(j) / Float(n) * 2 - 1) * .pi / 4)
                let dir = simd_normalize(nrm + u * a + v * b)
                let p = radius(dir)
                s.add(p, dir, V2(simd_dot(p, u), simd_dot(p, v)))
            }}
            let row = UInt32(n + 1)
            for j in 0..<UInt32(n) { for i in 0..<UInt32(n) {
                let a = base + j * row + i
                s.quad(a, a + 1, a + row + 1, a + row)
            }}
        }
        s.recomputeNormals()
        s.computeTangents()
        return s
    }

    /// Heightfield grid centered at origin, XZ extent `size`, UV in meters.
    public static func terrain(size: V2, segments: Int, material: MaterialKey, height: (V2) -> Float) -> Surface {
        var s = Surface(material: material)
        for j in 0...segments { for i in 0...segments {
            let x = (Float(i) / Float(segments) - 0.5) * size.x, z = (Float(j) / Float(segments) - 0.5) * size.y
            s.add(V3(x, height(V2(x, z)), z), .up, V2(x, -z))
        }}
        let row = UInt32(segments + 1)
        for j in 0..<UInt32(segments) { for i in 0..<UInt32(segments) {
            let a = j * row + i
            s.quad(a, a + row, a + row + 1, a + 1)
        }}
        s.recomputeNormals(weldSeams: false)
        s.computeTangents()
        return s
    }

    /// Single double-sided card (two triangles); orientation from `x`. UVs map to an atlas cell.
    public static func card(width: Float, height: Float, cell: (origin: V2, size: V2), material: MaterialKey,
                            normal: V3? = nil, extra: V2 = .zero) -> Surface {
        var s = Surface(material: material)
        let n = normal ?? V3(0, 0, 1)
        let w = width / 2, o = cell.origin, z = cell.size
        let a = s.add(V3(-w, 0, 0), n, V2(o.x, o.y), extra: extra)
        let b = s.add(V3(w, 0, 0), n, V2(o.x + z.x, o.y), extra: extra)
        let c = s.add(V3(w, height, 0), n, V2(o.x + z.x, o.y + z.y), extra: extra)
        let d = s.add(V3(-w, height, 0), n, V2(o.x, o.y + z.y), extra: extra)
        s.quad(a, b, c, d)
        return s
    }
}
