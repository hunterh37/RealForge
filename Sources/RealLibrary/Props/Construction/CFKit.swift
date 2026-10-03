import simd
import Foundation

/// Geometry helpers shared by the Construction and Farm packs.
enum CFKit {
    /// Extrudes a closed (z, y) profile, counter-clockwise with z right and y up, along +X through `xs`.
    /// `shape(ring, x, point, p)` may move each profile point per ring (chips, slots, sag).
    /// UVs: U = x, V = perimeter length, both in meters. Caps are flat with their own normals.
    static func extrude(_ profile: [V2], xs: [Float], material: MaterialKey, caps: Bool = true,
                        shape: ((Int, Float, Int, V2) -> V2)? = nil) -> Surface {
        let n = profile.count
        var vAcc: [Float] = [0]
        for i in 1...n { vAcc.append(vAcc[i - 1] + simd_distance(profile[i % n], profile[i - 1])) }
        var side = Surface(material: material)
        var rings: [[V2]] = []
        for (r, x) in xs.enumerated() {
            let ring = (0..<n).map { i in shape?(r, x, i, profile[i]) ?? profile[i] }
            rings.append(ring)
            for i in 0...n { let p = ring[i % n]; side.add(V3(x, p.y, p.x), .up, V2(x, vAcc[i])) }
        }
        let row = UInt32(n + 1)
        for r in 0..<(xs.count - 1) { for i in 0..<n {
            let a = UInt32(r) * row + UInt32(i)
            side.quad(a, a + row, a + row + 1, a + 1)
        }}
        side.recomputeNormals()
        side.computeTangents()
        guard caps, let first = rings.first, let last = rings.last, let x0 = xs.first, let x1 = xs.last else { return side }
        for (ring, x, sign) in [(first, x0, Float(-1)), (last, x1, Float(1))] {
            var cap = Surface(material: material)
            let c = ring.reduce(V2.zero, +) / Float(n)
            let nrm = V3(sign, 0, 0)
            let ci = cap.add(V3(x, c.y, c.x), nrm, V2(c.x * sign, c.y))
            for p in ring { cap.add(V3(x, p.y, p.x), nrm, V2(p.x * sign, p.y)) }
            for i in 0..<UInt32(n) {
                let a = 1 + i, b = 1 + (i + 1) % UInt32(n)
                if sign > 0 { cap.tri(ci, b, a) } else { cap.tri(ci, a, b) }
            }
            cap.computeTangents()
            side.append(cap)
        }
        return side
    }

    /// Superellipsoid (rounded box) of half extents `half`; `power` 2 = ellipsoid, 8+ = boxy.
    /// `displace(p)` pushes each point along its direction from the center, in meters.
    static func blob(half: V3, power: Float, subdivisions: Int, material: MaterialKey,
                     displace: ((V3) -> Float)? = nil) -> Surface {
        Prim.cubeSphere(subdivisions: subdivisions, material: material) { d in
            let a = simd_abs(d)
            let k = pow(pow(a.x, power) + pow(a.y, power) + pow(a.z, power), 1 / power)
            var p = d / max(k, 1e-5) * half
            if let displace { p += simd_normalize(p) * displace(p) }
            return p
        }
    }

    /// Closed loop tube (rings, hoops, twine bands) through `points` (not repeated at the end).
    static func loop(_ points: [V3], radius: Float, sides: Int, material: MaterialKey, seamTile: Float = 0.05) -> Surface {
        var s = Prim.tube(points + [points[0]], radii: Array(repeating: radius, count: points.count + 1), sides: sides,
                          seamTile: seamTile, material: material, capEnd: false)
        s.computeTangents()
        return s
    }

    /// Open tube through control points, smoothed with Catmull-Rom.
    static func pipe(_ control: [V3], radius: Float, sides: Int, per: Int = 6, material: MaterialKey, seamTile: Float = 0.1) -> Surface {
        let path = control.count > 2 ? catmull(control, per: per) : control
        var s = Prim.tube(path, radii: Array(repeating: radius, count: path.count), sides: sides, seamTile: seamTile, material: material)
        s.computeTangents()
        return s
    }
}

extension CFKit {
    /// Replaces each corner of a closed polygon with two points `b` meters back along its edges.
    static func bevel(_ poly: [V2], _ b: Float) -> [V2] {
        var out: [V2] = []
        let n = poly.count
        for i in 0..<n {
            let p = poly[i], a = poly[(i + n - 1) % n], c = poly[(i + 1) % n]
            let ba = min(b, simd_distance(a, p) * 0.45), bc = min(b, simd_distance(c, p) * 0.45)
            out.append(p + simd_normalize(a - p) * ba)
            out.append(p + simd_normalize(c - p) * bc)
        }
        return out
    }

    /// Point on a superellipse of half extents `half` and exponent `power` at angle `a`.
    static func superellipse(_ a: Float, half: V2, power: Float) -> V2 {
        let c = cos(a), s = sin(a)
        let k = pow(pow(abs(c), power) + pow(abs(s), power), 1 / power)
        return V2(c, s) / k * half
    }
}

extension CFKit {
    /// Flips any triangle whose face normal points against `outward(centroid)`, then rebuilds normals.
    static func orient(_ s: inout Surface, outward: (V3) -> V3) {
        for t in stride(from: 0, to: s.indices.count, by: 3) {
            let a = s.positions[Int(s.indices[t])], b = s.positions[Int(s.indices[t + 1])], c = s.positions[Int(s.indices[t + 2])]
            let n = simd_cross(b - a, c - a)
            if simd_dot(n, outward((a + b + c) / 3)) < 0 { s.indices.swapAt(t + 1, t + 2) }
        }
        s.recomputeNormals()
        s.computeTangents()
    }

    /// Wall swept around a closed XZ outline: `profile` is (outward offset, y) from bottom to top.
    /// U = outline length, V = profile length (meters). Faces point along +offset when `outwardFacing`.
    static func wall(_ outline: [V2], profile: [V2], material: MaterialKey, outwardFacing: Bool = true) -> Surface {
        let n = outline.count
        var normals: [V2] = []
        for i in 0..<n {
            let d = outline[(i + 1) % n] - outline[(i + n - 1) % n]
            normals.append(simd_normalize(V2(d.y, -d.x)))
        }
        // Make the normals point away from the outline centroid.
        let c = outline.reduce(V2.zero, +) / Float(n)
        if simd_dot(normals[0], outline[0] - c) < 0 { normals = normals.map { -$0 } }
        var uAcc: [Float] = [0]
        for i in 1...n { uAcc.append(uAcc[i - 1] + simd_distance(outline[i % n], outline[i - 1])) }
        var vAcc: [Float] = [0]
        for j in 1..<profile.count { vAcc.append(vAcc[j - 1] + simd_distance(profile[j], profile[j - 1])) }
        var s = Surface(material: material)
        for (j, pr) in profile.enumerated() {
            for i in 0...n {
                let o = outline[i % n] + normals[i % n] * pr.x
                s.add(V3(o.x, pr.y, o.y), .up, V2(uAcc[i], vAcc[j]))
            }
        }
        let row = UInt32(n + 1)
        for j in 0..<(profile.count - 1) { for i in 0..<n {
            let a = UInt32(j) * row + UInt32(i)
            s.quad(a, a + 1, a + row + 1, a + row)
        }}
        let sign: Float = outwardFacing ? 1 : -1
        orient(&s) { p in V3(p.x - c.x, 0, p.z - c.y) * sign }
        return s
    }
}

extension CFKit {
    /// Rounded rectangle in XZ, counter-clockwise from above, `perCorner` points per corner arc.
    static func roundedRect(center: V2, half: V2, radius: Float, perCorner: Int) -> [V2] {
        let r = min(radius, min(half.x, half.y) * 0.99)
        let cs: [(V2, Float)] = [(V2(half.x - r, half.y - r), 0), (V2(-half.x + r, half.y - r), .pi / 2),
                                 (V2(-half.x + r, -half.y + r), .pi), (V2(half.x - r, -half.y + r), 1.5 * .pi)]
        var out: [V2] = []
        for (c, a0) in cs { for k in 0...perCorner { let a = a0 + Float(k) / Float(perCorner) * .pi / 2; out.append(center + c + V2(cos(a), sin(a)) * r) } }
        return out
    }

    /// Lofts rings of equal point count (XZ outline at height y) into a tube-like skin. Faces point away
    /// from each ring's centroid when `outward`, toward it otherwise. U = ring length, V = height.
    static func loft(_ rings: [([V2], Float)], material: MaterialKey, outward: Bool = true) -> Surface {
        var s = Surface(material: material)
        let n = rings[0].0.count
        var v: Float = 0
        var cents: [V3] = []
        for (j, (ring, y)) in rings.enumerated() {
            if j > 0 { v += abs(y - rings[j - 1].1) + simd_distance(ring[0], rings[j - 1].0[0]) * 0.5 }
            var u: Float = 0
            for i in 0...n {
                if i > 0 { u += simd_distance(ring[i % n], ring[i - 1]) }
                s.add(V3(ring[i % n].x, y, ring[i % n].y), .up, V2(u, v))
            }
            let c = ring.reduce(V2.zero, +) / Float(n)
            cents.append(V3(c.x, y, c.y))
        }
        let row = UInt32(n + 1)
        for j in 0..<(rings.count - 1) { for i in 0..<n {
            let a = UInt32(j) * row + UInt32(i)
            s.quad(a, a + 1, a + row + 1, a + row)
        }}
        let c = cents.reduce(V3.zero, +) / Float(cents.count)
        let sign: Float = outward ? 1 : -1
        orient(&s) { p in V3(p.x - c.x, 0, p.z - c.z) * sign }
        return s
    }
}
