import simd
import Foundation

/// Flat ground-overlay helpers for sports fields: fans, disks, strips and outlines in the XZ plane,
/// facing +Y, UVs in meters (optionally rotated so mowing bands follow the foul lines).
enum BallKit {
    /// UV for a ground point. `rotated` maps to (along first-base line, along third-base line).
    static func uv(_ p: V2, rotated: Bool) -> V2 {
        rotated ? V2((p.x - p.y) * 0.70710678, (-p.x - p.y) * 0.70710678) : V2(p.x, -p.y)
    }

    /// Fan-triangulated polygon (star-shaped about `center`), points as (x, z), flat at `y`.
    static func fan(_ outline: [V2], center: V2, y: Float, material: MaterialKey, rotatedUV: Bool = false) -> Surface {
        var s = Surface(material: material)
        let c = s.add(V3(center.x, y, center.y), .up, uv(center, rotated: rotatedUV))
        let first = UInt32(s.vertexCount)
        for p in outline { _ = s.add(V3(p.x, y, p.y), .up, uv(p, rotated: rotatedUV)) }
        let n = UInt32(outline.count)
        for i in 0..<n { upTri(&s, c, first + i, first + (i + 1) % n) }
        s.computeTangents()
        return s
    }

    /// Ring band between two outlines sampled at the same angles (outer and inner), flat at `y`.
    static func band(outer: [V2], inner: [V2], y: Float, material: MaterialKey, closed: Bool = true, rotatedUV: Bool = false) -> Surface {
        var s = Surface(material: material)
        for (o, i) in zip(outer, inner) {
            _ = s.add(V3(o.x, y, o.y), .up, uv(o, rotated: rotatedUV)); _ = s.add(V3(i.x, y, i.y), .up, uv(i, rotated: rotatedUV))
        }
        let n = UInt32(outer.count)
        for k in 0..<(closed ? n : n - 1) {
            let a = 2 * k, b = 2 * ((k + 1) % n)
            upTri(&s, a, a + 1, b + 1); upTri(&s, a, b + 1, b)
        }
        s.computeTangents()
        return s
    }

    /// Polar-grid disk with a radial height profile (mounds, circles). `h(r)` added to `y`.
    static func disk(center: V2, radius: Float, y: Float, rings: Int = 4, sectors: Int = 40, material: MaterialKey,
                     height: (Float) -> Float = { _ in 0 }) -> Surface {
        var s = Surface(material: material)
        _ = s.add(V3(center.x, y + height(0), center.y), .up, uv(center, rotated: false))
        for r in 1...rings {
            let rr = radius * Float(r) / Float(rings)
            for k in 0..<sectors {
                let a = Float(k) / Float(sectors) * 2 * .pi
                let p = center + V2(cos(a), sin(a)) * rr
                _ = s.add(V3(p.x, y + height(rr), p.y), .up, uv(p, rotated: false))
            }
        }
        let S = UInt32(sectors)
        for k in 0..<S { upTri(&s, 0, 1 + k, 1 + (k + 1) % S) }
        for r in 1..<UInt32(rings) {
            let a0 = 1 + (r - 1) * S, a1 = 1 + r * S
            for k in 0..<S {
                let k1 = (k + 1) % S
                upTri(&s, a0 + k, a1 + k, a1 + k1); upTri(&s, a0 + k, a1 + k1, a0 + k1)
            }
        }
        s.recomputeNormals(weldSeams: false)
        s.computeTangents()
        return s
    }

    /// Straight strip of `width` from a to b at height y (chalk lines, base paths).
    static func strip(_ a: V2, _ b: V2, width: Float, y: Float, material: MaterialKey) -> Surface {
        let d = simd_normalize(b - a), n = V2(-d.y, d.x) * (width / 2)
        return quad([a - n, b - n, b + n, a + n], y: y, material: material)
    }

    /// Convex quad (any winding) at height y.
    static func quad(_ p: [V2], y: Float, material: MaterialKey) -> Surface {
        var s = Surface(material: material)
        for q in p { _ = s.add(V3(q.x, y, q.y), .up, uv(q, rotated: false)) }
        upTri(&s, 0, 1, 2); upTri(&s, 0, 2, 3)
        s.computeTangents()
        return s
    }

    /// Rectangle outline of chalk (4 strips) with corners at a..d in order.
    static func outline(_ c: [V2], width: Float, y: Float, material: MaterialKey) -> Surface {
        var s = Surface(material: material)
        for i in 0..<c.count {
            let a = c[i], b = c[(i + 1) % c.count], d = simd_normalize(b - a)
            s.append(strip(a - d * width / 2, b + d * width / 2, width: width, y: y, material: material))
        }
        return s
    }

    /// Vertical skirt hanging from an outline (lips where turf meets clay).
    static func skirt(_ outline: [V2], top: Float, bottom: Float, material: MaterialKey) -> Surface {
        var s = Surface(material: material)
        let n = outline.count
        var dist: Float = 0
        for i in 0...n {
            let p = outline[i % n]
            if i > 0 { dist += simd_length(p - outline[i - 1]) }
            _ = s.add(V3(p.x, top, p.y), .up, V2(dist, top)); _ = s.add(V3(p.x, bottom, p.y), .up, V2(dist, bottom))
        }
        for i in 0..<UInt32(n) {
            let a = 2 * i
            s.quad(a, a + 1, a + 3, a + 2)
        }
        s.recomputeNormals(weldSeams: false)
        // Face outward from the region: flip if normals point at the centroid.
        let c = outline.reduce(V2.zero, +) / Float(n)
        let p0 = s.positions[0], n0 = s.normals[0]
        if simd_dot(V2(n0.x, n0.z), V2(p0.x, p0.z) - c) < 0 { s = s.flipped() }
        s.computeTangents()
        return s
    }

    /// Boundary of a star-shaped region seen from `center`: march each ray outward, then bisect.
    static func rayOutline(center: V2, count: Int, maxRadius: Float, step: Float = 0.25, inside: (V2) -> Bool) -> [V2] {
        (0..<count).map { k in
            let a = Float(k) / Float(count) * 2 * .pi
            let d = V2(sin(a), -cos(a))
            var r0: Float = 0, r1 = step
            while r1 < maxRadius, inside(center + d * r1) { r0 = r1; r1 += step }
            for _ in 0..<12 { let m = (r0 + r1) / 2; if inside(center + d * m) { r0 = m } else { r1 = m } }
            return center + d * r0
        }
    }

    /// Straight round pipe from a to b.
    static func pipe(_ a: V3, _ b: V3, radius: Float, sides: Int = 10, material: MaterialKey) -> Surface {
        Prim.tube([a, b], radii: [radius, radius], sides: sides, seamTile: 0.3, material: material, capEnd: true)
    }

    /// Flat panel spanning a (bottom-left), b (bottom-right) up to height h; UV in meters (u along a->b, v up).
    /// Single-sided toward the side where (b - a) x up points; cutout materials are two-sided anyway.
    static func panel(_ a: V3, _ b: V3, height h: Float, material: MaterialKey) -> Surface {
        var s = Surface(material: material)
        let len = simd_length(b - a), up = V3(0, 1, 0)
        let n = simd_normalize(simd_cross(b - a, up))
        _ = s.add(a, n, V2(0, 0)); _ = s.add(b, n, V2(len, 0)); _ = s.add(b + up * h, n, V2(len, h)); _ = s.add(a + up * h, n, V2(0, h))
        let pa = s.positions[0], pb = s.positions[1], pc = s.positions[2]
        if simd_dot(simd_cross(pb - pa, pc - pa), n) >= 0 { s.quad(0, 1, 2, 3) } else { s.quad(0, 3, 2, 1) }
        s.computeTangents()
        return s
    }

    /// Chain-link panel: alpha-tested wire mesh plus a faint transparent veil 2 mm behind it.
    static func fence(_ a: V3, _ b: V3, height h: Float, material: MaterialKey) -> Model {
        var m = Model(name: "fence")
        m.add(panel(a, b, height: h, material: material))
        let veil: MaterialKey = material.hasPrefix("fence.chainlink-vinyl:") ? "fence.chainlink-veil-yellow"
            : material.hasPrefix("fence.chainlink-vinyl") ? "fence.chainlink-veil" : "fence.chainlink-veil-light"
        let n = simd_normalize(simd_cross(b - a, V3(0, 1, 0))) * 0.002
        m.add(panel(a - n, b - n, height: h, material: veil))
        return m
    }

    /// X/Z center of a model's bounds.
    static func centerXZ(_ m: Model) -> V2 {
        let b = m.bounds
        return V2((b.min.x + b.max.x) / 2, (b.min.z + b.max.z) / 2)
    }

    /// Triangle facing +Y regardless of the given winding.
    static func upTri(_ s: inout Surface, _ a: UInt32, _ b: UInt32, _ c: UInt32) {
        let pa = s.positions[Int(a)], pb = s.positions[Int(b)], pc = s.positions[Int(c)]
        if simd_cross(pb - pa, pc - pa).y >= 0 { s.tri(a, b, c) } else { s.tri(a, c, b) }
    }
}
