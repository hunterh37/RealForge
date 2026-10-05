import simd
import RealCore

/// Watertight shells for food assets. Runtime slicing caps each cut with a polygon traced from the
/// cut edges, so every surface these builders return is a closed, consistently wound manifold
/// (seam and pole vertices are duplicated for UVs but share exact positions). Triangles stay near
/// equilateral: rings carry a vertex count proportional to their perimeter and are stitched by arc
/// fraction, and poles are fans from a ring sized to the target edge.
public enum FoodMesh {
    /// Stitches closed loops (bottom to top, each without a repeated end point) into one shell closed
    /// by fans to `start` and `end`. U is the arc fraction around each loop times `uTotal`; V is `v[i]`.
    /// Loops wind like `Prim.lathe` (counterclockwise seen from `end`) for outward faces.
    public static func loft(_ rings: [[V3]], v: [Float], start: V3, end: V3, startV: Float, endV: Float,
                            uTotal: Float, material: MaterialKey) -> Surface {
        var s = Surface(material: material)
        var rowIdx: [[UInt32]] = [], rowT: [[Float]] = []
        for (i, ring) in rings.enumerated() {
            var cum: [Float] = [0]
            for k in 0..<ring.count { cum.append(cum[k] + simd_distance(ring[k], ring[(k + 1) % ring.count])) }
            let per = max(cum.last!, 1e-9)
            var idx: [UInt32] = [], ts: [Float] = []
            for k in 0...ring.count {
                let t = cum[k] / per
                idx.append(s.add(ring[k % ring.count], .up, V2(t * uTotal, v[i])))
                ts.append(t)
            }
            rowIdx.append(idx); rowT.append(ts)
        }
        // Start pole: one vertex per fan triangle (same position) so U does not swirl.
        let r0 = rowIdx[0], t0 = rowT[0]
        for k in 0..<(r0.count - 1) {
            let p = s.add(start, .up, V2((t0[k] + t0[k + 1]) / 2 * uTotal, startV))
            s.tri(p, r0[k + 1], r0[k])
        }
        for i in 0..<(rings.count - 1) {
            let a = rowIdx[i], b = rowIdx[i + 1], ta = rowT[i], tb = rowT[i + 1]
            var x = 0, y = 0
            let na = a.count - 1, nb = b.count - 1
            while x < na || y < nb {
                if y == nb || (x < na && ta[x + 1] <= tb[y + 1]) {
                    s.tri(a[x], a[x + 1], b[y]); x += 1
                } else {
                    s.tri(a[x], b[y + 1], b[y]); y += 1
                }
            }
        }
        let rl = rowIdx[rings.count - 1], tl = rowT[rings.count - 1]
        for k in 0..<(rl.count - 1) {
            let p = s.add(end, .up, V2((tl[k] + tl[k + 1]) / 2 * uTotal, endV))
            s.tri(rl[k], rl[k + 1], p)
        }
        s.recomputeNormals()
        s.computeTangents()
        return s
    }

    /// Closed surface of revolution around +Y. `curve(t)` for t in 0...1 gives (radius, y) from the
    /// bottom pole (radius 0) to the top pole (radius 0). Rings are spaced `edge` apart along the curve.
    public static func revolve(edge: Float, seamTile: Float = 0.1, material: MaterialKey, curve: (Float) -> V2) -> Surface {
        let dense = (0...600).map { curve(Float($0) / 600) }
        var cum: [Float] = [0]
        for i in 1..<dense.count { cum.append(cum[i - 1] + simd_distance(dense[i], dense[i - 1])) }
        let L = cum.last!
        let n = max(2, Int((L / edge).rounded()) - 1)
        let rMax = dense.map(\.x).max() ?? edge
        var rings: [[V3]] = [], vs: [Float] = []
        var j = 0
        for i in 1...n {
            let s = L * Float(i) / Float(n + 1)
            while j < dense.count - 2 && cum[j + 1] < s { j += 1 }
            let f = (s - cum[j]) / max(cum[j + 1] - cum[j], 1e-9)
            let q = dense[j] + (dense[j + 1] - dense[j]) * f
            let r = max(q.x, edge * 0.3)
            let cnt = max(6, Int((2 * .pi * r / edge).rounded()))
            rings.append((0..<cnt).map { k in let a = Float(k) / Float(cnt) * 2 * .pi; return V3(r * cos(a), q.y, -r * sin(a)) })
            vs.append(s)
        }
        let circ = 2 * Float.pi * rMax
        let uTotal = circ < seamTile * 0.75 ? circ : max(seamTile, (circ / seamTile).rounded() * seamTile)
        let a = dense[0], b = dense[dense.count - 1]
        return loft(rings, v: vs, start: V3(0, a.y, 0), end: V3(0, b.y, 0), startV: 0, endV: L, uTotal: uTotal, material: material)
    }

    /// Closed shell lofted along +Y through cross-sections: `section(s)` for s in 0...1 returns the
    /// (half-width x, half-depth z) of a superellipse at height `y(s)`, exponent `e(s)`. The ends close at
    /// points; loops are resampled to equal arc steps of `edge`.
    public static func sections(edge: Float, length: Float, seamTile: Float = 0.1, material: MaterialKey,
                                section: (Float) -> (w: Float, d: Float, e: Float, offset: V2)) -> Surface {
        // Place rings at equal arc steps along the outline (length vs. the larger half-extent) so steep
        // rounded ends get as many rings as their curvature needs.
        let dense = (0...600).map { k -> V2 in let s = Float(k) / 600; let q = section(s); return V2(s * length, max(q.w, q.d)) }
        var cum: [Float] = [0]
        for k in 1..<dense.count { cum.append(cum[k - 1] + simd_distance(dense[k], dense[k - 1])) }
        let L = cum.last!
        let n = max(2, Int((L / edge).rounded()) - 1)
        var rings: [[V3]] = [], vs: [Float] = []
        var maxPer: Float = 0
        var j = 0
        for i in 1...n {
            let target = L * Float(i) / Float(n + 1)
            while j < dense.count - 2 && cum[j + 1] < target { j += 1 }
            let f = (target - cum[j]) / max(cum[j + 1] - cum[j], 1e-9)
            let s = (Float(j) + f) / 600
            let sec = section(s)
            let outline: [V2] = (0..<256).map { k in
                let a = Float(k) / 256 * 2 * .pi
                let c = cos(a), sn = sin(a)
                return V2(sec.w * copysign(pow(abs(c), 2 / sec.e), c), -sec.d * copysign(pow(abs(sn), 2 / sec.e), sn))
            }
            let loop = resampleLoop(outline, step: edge, minCount: 6)
            var per: Float = 0
            for k in 0..<loop.count { per += simd_distance(loop[k], loop[(k + 1) % loop.count]) }
            maxPer = max(maxPer, per)
            rings.append(loop.map { V3($0.x + sec.offset.x, s * length, $0.y + sec.offset.y) })
            vs.append(s * length)
        }
        let uTotal = maxPer < seamTile * 0.75 ? maxPer : max(seamTile, (maxPer / seamTile).rounded() * seamTile)
        let s0 = section(0).offset, s1 = section(1).offset
        return loft(rings, v: vs, start: V3(s0.x, 0, s0.y), end: V3(s1.x, length, s1.y), startV: 0, endV: length, uTotal: uTotal, material: material)
    }

    /// Resamples a closed 2D loop (no repeated end point) to equal arc steps near `step`, starting at `pts[0]`.
    public static func resampleLoop(_ pts: [V2], step: Float, minCount: Int = 6) -> [V2] {
        var cum: [Float] = [0]
        for k in 0..<pts.count { cum.append(cum[k] + simd_distance(pts[k], pts[(k + 1) % pts.count])) }
        let per = cum.last!
        let cnt = max(minCount, Int((per / step).rounded()))
        var out: [V2] = []
        var j = 0
        for i in 0..<cnt {
            let s = per * Float(i) / Float(cnt)
            while j < pts.count - 1 && cum[j + 1] < s { j += 1 }
            let a = pts[j], b = pts[(j + 1) % pts.count]
            let f = (s - cum[j]) / max(cum[j + 1] - cum[j], 1e-9)
            out.append(a + (b - a) * f)
        }
        return out
    }

    /// Closed round tube along `path` with per-point radius; ends close at points pushed out by
    /// `endBulge` x radius (0 = flat cut end, 1 = hemispherical). `sides` around.
    public static func tube(_ path: [V3], radii: [Float], sides: Int, endBulge: Float = 0.6, seamTile: Float = 0.02,
                            material: MaterialKey) -> Surface {
        precondition(path.count >= 2 && radii.count == path.count)
        var tangents: [V3] = []
        for i in path.indices {
            let a = path[max(0, i - 1)], b = path[min(path.count - 1, i + 1)]
            tangents.append(simd_normalize(b - a))
        }
        var normal = tangents[0].anyPerpendicular
        var rings: [[V3]] = [], vs: [Float] = []
        var v: Float = 0
        for i in path.indices {
            if i > 0 {
                v += simd_distance(path[i], path[i - 1])
                let t0 = tangents[i - 1], t1 = tangents[i]
                let axis = simd_cross(t0, t1), sl = simd_length(axis)
                if sl > 1e-6 { normal = simd_quatf(angle: atan2(sl, simd_dot(t0, t1)), axis: axis / sl).act(normal) }
                normal = simd_normalize(normal - t1 * simd_dot(normal, t1))
            }
            let bin = simd_cross(tangents[i], normal)
            rings.append((0..<sides).map { k in
                let a = Float(k) / Float(sides) * 2 * .pi
                return path[i] + (normal * cos(a) + bin * sin(a)) * radii[i]
            })
            vs.append(v)
        }
        let circ = 2 * Float.pi * (radii.max() ?? 0.001)
        let uTotal = circ < seamTile * 0.75 ? circ : max(seamTile, (circ / seamTile).rounded() * seamTile)
        let st = path[0] - tangents[0] * radii[0] * endBulge
        let en = path[path.count - 1] + tangents[path.count - 1] * radii[radii.count - 1] * endBulge
        return loft(rings, v: vs, start: st, end: en, startV: -radii[0] * endBulge, endV: v + radii[radii.count - 1] * endBulge,
                    uTotal: uTotal, material: material)
    }

    /// Rounded box centered at the origin with every face subdivided near `edge` (no long slivers).
    /// `extra[axis]` adds sample coordinates (grooves, score lines) so features land on vertices.
    public static func box(_ size: V3, radius: Float, edge: Float, bevelSegments: Int = 3, extra: [[Float]] = [[], [], []],
                           material: MaterialKey) -> Surface {
        let h = size / 2, r = min(radius, h.min() * 0.999)
        let inner = h - V3(repeating: r)
        func samples(_ ax: Int) -> [Float] {
            let half = h[ax]
            var a: [Float] = []
            for k in 0...bevelSegments { a.append(-half + r * (1 - cos(Float(k) / Float(bevelSegments) * .pi / 2))) }
            let lo = -half + r, hi = half - r
            let n = max(1, Int(((hi - lo) / edge).rounded()))
            for k in 1..<n { a.append(lo + (hi - lo) * Float(k) / Float(n)) }
            for k in 0...bevelSegments { a.append(half - r * (1 - cos(Float(bevelSegments - k) / Float(bevelSegments) * .pi / 2))) }
            var interior = Set((bevelSegments + 1)..<(a.count - bevelSegments - 1))
            for e in extra[ax] where e > lo + edge * 0.1 && e < hi - edge * 0.1 {
                if let j = interior.min(by: { abs(a[$0] - e) < abs(a[$1] - e) }), abs(a[j] - e) < edge * 0.5 {
                    a[j] = e; interior.remove(j)
                } else { a.append(e) }
            }
            a.sort()
            let out = a
            return out
        }
        let axisSamples = [samples(0), samples(1), samples(2)]
        var s = Surface(material: material)
        let faces: [(Int, Float, Int, Int)] = [(0, 1, 2, 1), (0, -1, 2, 1), (1, 1, 0, 2), (1, -1, 0, 2), (2, 1, 0, 1), (2, -1, 0, 1)]
        for (ax, sign, ua, va) in faces {
            let us = axisSamples[ua], vsm = axisSamples[va]
            let base = UInt32(s.positions.count)
            for v in vsm { for u in us {
                var p = V3.zero
                p[ax] = sign * h[ax]; p[ua] = u; p[va] = v
                let c = simd_clamp(p, -inner, inner)
                let d = p - c
                var n = V3.zero; n[ax] = sign
                if simd_length(d) > 1e-7 { n = simd_normalize(d) }
                let q = c + n * r
                var uv = V2(q[ua], q[va])
                if sign < 0 { uv.x = -uv.x }
                s.add(q, n, uv)
            }}
            let nu = us.count
            var cu = V3.zero, cv = V3.zero, fa = V3.zero; cu[ua] = 1; cv[va] = 1; fa[ax] = sign
            let outward = simd_dot(simd_cross(cu, cv), fa) > 0
            for j in 0..<(vsm.count - 1) { for i in 0..<(nu - 1) {
                let a = base + UInt32(j * nu + i), b = a + 1, c = a + UInt32(nu) + 1, d = a + UInt32(nu)
                // Alternate the diagonal so the grid has no directional bias.
                let flip = (i + j) % 2 == 1
                if outward {
                    if flip { s.tri(a, b, d); s.tri(b, c, d) } else { s.quad(a, b, c, d) }
                } else {
                    if flip { s.tri(a, d, b); s.tri(b, d, c) } else { s.quad(a, d, c, b) }
                }
            }}
        }
        s.recomputeNormals()
        s.computeTangents()
        return s
    }

    /// Offset copy along the welded vertex normals: a skin over flesh (`d` > 0) or the inner wall of a
    /// thick shell (`d` < 0, then `flipped()`). Topology is shared, so the copy stays closed.
    public static func offset(_ s: Surface, by d: Float, material: MaterialKey? = nil) -> Surface {
        var o = s
        if let material { o.material = material }
        o.positions = s.positions.indices.map { s.positions[$0] + s.normals[$0] * d }
        o.recomputeNormals()
        o.computeTangents()
        return o
    }

    /// Thick-walled shell: `outer` plus its inward offset by `wall`, wound inward. Both loops stay closed.
    public static func hollow(_ outer: Surface, wall: Float) -> Surface {
        var s = outer
        s.append(offset(outer, by: -wall).flipped())
        return s
    }

    /// Rotates a shell built along +Y so it lies along +X: (x, y, z) -> (y, -x, z).
    public static func layAlongX(_ s: Surface) -> Surface {
        var o = s
        o.positions = s.positions.map { V3($0.y, -$0.x, $0.z) }
        o.normals = s.normals.map { V3($0.y, -$0.x, $0.z) }
        o.computeTangents()
        return o
    }

    /// Scales a shell to `size` (bounding box) and moves it to base y = 0, centered on X/Z.
    public static func fit(_ s: Surface, size: V3) -> Surface {
        let bb = s.bounds
        let ext = simd_max(bb.max - bb.min, V3(repeating: 1e-6))
        let k = size / ext, c = (bb.min + bb.max) / 2
        var o = s
        o.deform { p in V3((p.x - c.x) * k.x, (p.y - bb.min.y) * k.y, (p.z - c.z) * k.z) }
        return o
    }

    /// Catmull-Rom smoothed profile through (radius, y) control points as a curve for `revolve`
    /// (t = 0 first point, t = 1 last point; first and last radius should be 0).
    public static func profile(_ pts: [V2], per: Int = 8) -> (Float) -> V2 {
        let sm = catmull(pts.map { V3($0.x, $0.y, 0) }, per: per).map { V2(max(0, $0.x), $0.y) }
        return { t in
            let f = min(max(t, 0), 1) * Float(sm.count - 1)
            let i = min(Int(f), sm.count - 2)
            return sm[i] + (sm[i + 1] - sm[i]) * (f - Float(i))
        }
    }
}
