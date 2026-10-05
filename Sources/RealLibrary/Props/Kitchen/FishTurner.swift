import simd
import Foundation

/// Slotted offset fish turner lying on a counter: a thin satin stainless blade with five fanned slots cut
/// through and an angled front edge thinned to 0.4 mm, an offset neck bent up from the blade, and a full
/// tang between oiled walnut scales with two brass rivets. Handle toward -X, blade toward +X; the blade
/// lies flat and the handle stands off the counter on the neck.
public struct FishTurner: RealAsset {
    public static let id = "fish-turner"
    public static let summary = "Slotted fish turner: thin fanned-slot stainless blade, angled edge, offset neck, walnut handle with brass rivets."
    public static let tags = ["prop", "kitchen", "cookware", "metal", "wood", "tool", "handheld"]
    public static let budget = 8000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 20, elevation: 40, distance: 0.85, studio: true)

    /// Blade length from the neck to the front edge (m).
    public var bladeLength: Float = 0.155
    /// Blade width at the front (m).
    public var bladeWidth: Float = 0.074
    /// Number of slots.
    public var slots: Int = 5
    /// Blade thickness (m).
    public var thickness: Float = 0.0009
    /// Handle length (m).
    public var handleLength: Float = 0.12
    public var blade: MaterialKey = "metal.knife-blade"
    public var wood: MaterialKey = "wood.walnut-oiled"
    public var rivets: MaterialKey = "metal.brass"
    public init() {}

    /// Middle of the blade (asset space).
    public var workPoint: V3 { placement().point(V3(bladeLength * 0.6, 0, 0)) }
    /// Middle of the handle (asset space).
    public var gripPoint: V3 { placement().point(V3(-0.062 - handleLength * 0.5, handleY, 0)) }

    var handleY: Float { 0.024 }

    func outline() -> [V2] {
        let L = bladeLength, w = bladeWidth / 2
        let pts = [V2(-0.01, -0.0068), V2(0.03, -0.018), V2(L * 0.6, -w * 0.94), V2(L - 0.008, -w), V2(L + 0.006, w), V2(L * 0.6, w * 0.94),
                   V2(0.03, 0.018), V2(-0.01, 0.0068)]
        return Shape2D.rounded(pts, radius: 0.007, segments: 4)
    }

    /// Outline with slots spliced in through zero-width bridges toward the fan origin (ear-clip ready).
    func slottedOutline(slotSegments: Int) -> [V2] {
        var poly = outline()
        let o = V2(-0.12, 0), r: Float = 0.0021
        for k in 0..<slots {
            let a = (Float(k) - Float(slots - 1) / 2) * 0.083
            let d = V2(cos(a), sin(a)), n = V2(-d.y, d.x)
            let A = o + d * (0.12 + 0.042), B = o + d * (0.12 + bladeLength * 0.86)
            var hole: [V2] = []
            for i in 0...slotSegments { let t = -Float.pi / 2 + Float(i) / Float(slotSegments) * .pi; hole.append(B + (d * cos(t) + n * sin(t)) * r) }
            for i in 0...slotSegments { let t = Float.pi / 2 + Float(i) / Float(slotSegments) * .pi; hole.append(A + (d * cos(t) + n * sin(t)) * r) }
            hole.reverse()                                                  // clockwise
            let rear = A - d * r
            let ri = hole.indices.min { simd_distance(hole[$0], rear) < simd_distance(hole[$1], rear) }!
            hole = Array(hole[ri...] + hole[..<ri])
            // Ray from the slot's rear point back toward the fan origin: nearest crossing of the boundary.
            let dir = -d
            var best: (Int, Float, V2)? = nil
            for i in poly.indices {
                let p = poly[i], q = poly[(i + 1) % poly.count], e = q - p
                let den = dir.x * e.y - dir.y * e.x
                guard abs(den) > 1e-9 else { continue }
                let w0 = p - hole[0]
                let t = (w0.x * e.y - w0.y * e.x) / den
                let u = (w0.x * dir.y - w0.y * dir.x) / den
                if t > 1e-5, u >= 0, u <= 1, t < (best?.1 ?? .infinity) { best = (i, t, hole[0] + dir * t) }
            }
            guard let (i, _, P) = best else { continue }
            poly = Array(poly[0...i]) + [P] + hole + [hole[0], P] + Array(poly[(i + 1)...])
        }
        return poly
    }

    func bladeSurface(slotSegments: Int) -> Surface {
        let pts = slottedOutline(slotSegments: slotSegments)
        let L = bladeLength
        func half(_ x: Float) -> Float { (thickness - (thickness - 0.0004) * smoothstep(L - 0.025, L, x)) / 2 }
        var s = Surface(material: blade)
        let tri = Shape2D.triangulate(pts)
        for side: Float in [1, -1] {
            let base = UInt32(s.positions.count)
            for p in pts { s.add(V3(p.x, side * half(p.x), p.y), V3(0, side, 0), V2(p.x, p.y)) }
            for t in stride(from: 0, to: tri.count, by: 3) {
                let a = base + tri[t], b = base + tri[t + 1], c = base + tri[t + 2]
                let n = simd_cross(s.positions[Int(b)] - s.positions[Int(a)], s.positions[Int(c)] - s.positions[Int(a)])
                if n.y * side >= 0 { s.tri(a, b, c) } else { s.tri(a, c, b) }
            }
        }
        // Walls (bridge walls face each other inside the blade and stay hidden).
        let ccw: Float = Shape2D.area(pts) >= 0 ? 1 : -1
        var u: Float = 0
        for i in pts.indices {
            let a = pts[i], b = pts[(i + 1) % pts.count]
            let len = simd_distance(a, b)
            guard len > 1e-6 else { continue }
            let d = (b - a) / len, out = V2(d.y, -d.x) * ccw
            let n3 = V3(out.x, 0, out.y)
            let i0 = s.add(V3(a.x, half(a.x), a.y), n3, V2(u, 0)), i1 = s.add(V3(b.x, half(b.x), b.y), n3, V2(u + len, 0))
            let i2 = s.add(V3(b.x, -half(b.x), b.y), n3, V2(u + len, 0.001)), i3 = s.add(V3(a.x, -half(a.x), a.y), n3, V2(u, 0.001))
            let fn = simd_cross(s.positions[Int(i1)] - s.positions[Int(i0)], s.positions[Int(i2)] - s.positions[Int(i0)])
            if simd_dot(fn, n3) >= 0 { s.quad(i0, i1, i2, i3) } else { s.quad(i0, i3, i2, i1) }
            u += len
        }
        s.computeTangents()
        return s
    }

    func oriented(_ s: Surface) -> Surface {
        var s = s
        if let i = s.positions.indices.max(by: { s.positions[$0].y < s.positions[$1].y }), s.normals[i].y < 0 { s = s.flipped() }
        return s
    }

    /// The blade lies flat on the counter; the offset neck holds the handle up off it.
    func placement() -> Xform {
        let xb = -0.062 - handleLength, xf = bladeLength + 0.006
        return Xform(translation: V3(-(xb + xf) / 2, thickness / 2, 0))
    }

    func model(detail: Bool) -> Model {
        var m = Model(name: Self.id)
        m.add(bladeSurface(slotSegments: detail ? 6 : 3))
        // Offset neck: a flat bar bent up from the blade into the handle.
        let neck = catmull([V3(0.004, 0, 0), V3(-0.012, 0.0008, 0), V3(-0.026, 0.01, 0), V3(-0.038, 0.019, 0), V3(-0.052, 0.0235, 0),
                            V3(-0.068, handleY, 0)], per: detail ? 5 : 3)
        m.add(Prim.sweep(Shape2D.roundedRect(0.0022, 0.012, radius: 0.0009, segments: 2), along: neck, up: .up, grainAlongPath: true, material: blade))
        // Handle: walnut scales lofted along -X with a steel tang line between them.
        let x0: Float = -0.062, n = detail ? 22 : 10, sides = detail ? 24 : 12
        var scales: [[V3]] = [], tang: [[V3]] = []
        for i in 0...n {
            let s = Float(i) / Float(n)
            var w: Float = 0.017 + 0.009 * sin(.pi * pow(s, 0.75))
            if s > 0.9 { w *= sqrt(max(0.05, 1 - pow((s - 0.9) / 0.1, 2))) }
            if s < 0.03 { w *= 0.85 + 5 * s }
            let h = w * 0.62 + 0.0015, x = x0 - handleLength * s
            scales.append(Shape2D.superellipse(w, h, exponent: 2.4, segments: sides).map { V3(x, handleY + $0.y, $0.x) })
            tang.append(Shape2D.superellipse(min(w + 0.0008, 0.0275), 0.0024, exponent: 8, segments: 12).map { V3(x + 0.0004, handleY + $0.y, $0.x) })
        }
        var sc = oriented(Prim.loft(scales, capStart: true, capEnd: true, material: wood))
        sc.uvs = sc.uvs.map { V2($0.y, $0.x) }
        sc.computeTangents()
        m.add(sc)
        m.add(oriented(Prim.loft(Array(tang.prefix(n)), capStart: true, capEnd: true, material: "metal.stainless")))
        if detail {
            for s in [Float(0.28), 0.68] {
                let x = x0 - handleLength * s
                let w: Float = 0.017 + 0.009 * sin(.pi * pow(s, 0.75)), h = w * 0.62 + 0.0015
                for side: Float in [1, -1] {
                    panRivet(&m, at: V3(x, handleY + side * (h / 2 - 0.0002), 0), normal: V3(0, side, 0), radius: 0.0027, height: 0.0004, material: rivets)
                }
            }
        }
        var out = Model(name: Self.id)
        let p = placement()
        for s in m.surfaces { out.surfaces.append(s.transformed(p)) }
        groundAO(&out, height: 0.015, floor: 0.6)
        return out
    }

    public func build(seed: UInt64) -> LODModel {
        LODModel(levels: [model(detail: true), model(detail: false)], switchDistances: [2])
    }
}
