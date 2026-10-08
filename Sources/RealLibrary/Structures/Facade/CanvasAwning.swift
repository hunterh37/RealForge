import simd
import Foundation

/// Shopfront canvas awning, 2.4 m x 1.0 m projection: 25 mm steel tube frame (wall rail on brackets,
/// end arms, front bar, intermediate ribs), striped acrylic canvas slope sagging slightly between
/// ribs, scalloped valance along the front and solid side cheeks. Wall plane at z = -projection/2,
/// the awning projects +Z; base y = 0 is the bottom of the valance scallops.
public struct CanvasAwning: RealAsset {
    public static let id = "canvas-awning"
    public static let summary = "Shopfront canvas awning, 2.4 m: steel tube frame on wall brackets, striped canvas slope and scalloped valance."
    public static let tags = ["structure", "architecture", "facade", "fabric", "metal", "urban"]
    public static let budget = 16_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 32, elevation: 12, distance: 1.0, studio: true)

    /// Width along the wall (m).
    public var width: Float = 2.4
    /// Projection from the wall (m).
    public var projection: Float = 1.0
    /// Height drop from the wall rail to the front bar (m).
    public var drop: Float = 0.62
    /// Valance depth (m).
    public var valance: Float = 0.24
    /// Stripe width (m).
    public var stripeWidth: Float = 0.15
    /// Canvas stripe colors (fabric keys with tints).
    public var stripeA: MaterialKey = "fabric.canvas:1F4E3D"
    public var stripeB: MaterialKey = "fabric.canvas:E9E2CF"
    public var frameMaterial: MaterialKey = "metal.wrought-iron"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id), lite = Model(name: Self.id + "-lite")
        let W = width, P = projection, zw = -P / 2
        let yFront = valance, yTop = valance + drop
        let ribs = max(1, Int((W / 0.8).rounded()))
        func both(_ s: Surface) { m.add(s); lite.add(s) }

        // Canvas surface point at (x, t) with t 0 at the wall, 1 at the front; sag between ribs.
        func canvas(_ x: Float, _ t: Float) -> V3 {
            let u = (x + W / 2) / W * Float(ribs)
            let between = sin(u.truncatingRemainder(dividingBy: 1) * .pi)
            let sag = 0.018 * between * sin(t * .pi)
            return V3(x, yTop + (yFront - yTop) * t - sag - 0.012 * sin(t * .pi), zw + P * t)
        }
        let nStripes = max(2, Int((W / stripeWidth).rounded()))
        let sw = W / Float(nStripes)
        let along = 10, across = 3
        for i in 0..<nStripes {
            let mat = i % 2 == 0 ? stripeA : stripeB
            var s = Surface(material: mat)
            let x0 = -W / 2 + Float(i) * sw
            for a in 0...along { for c in 0...across {
                let t = Float(a) / Float(along), x = x0 + sw * Float(c) / Float(across)
                let p = canvas(x, t)
                _ = s.add(p, .up, V2(x, t * P))
            }}
            let row = UInt32(across + 1)
            for a in 0..<along { for c in 0..<across {
                let i0 = UInt32(a) * row + UInt32(c)
                s.quad(i0, i0 + row, i0 + row + 1, i0 + 1)
            }}
            s.recomputeNormals(weldSeams: false)
            s.computeTangents()
            both(s); both(s.flipped())

            // Valance with a scalloped hem, one scallop per stripe.
            var hem: [V2] = [V2(0, valance), V2(0, 0.06)]
            for k in 0...8 { let t = Float(k) / 8 * .pi; hem.append(V2(sw / 2 - cos(t) * sw / 2, 0.06 - sin(t) * 0.06)) }
            hem.append(V2(sw, valance))
            let v = Prim.extrude(Array(hem.reversed()), depth: 0.002, bevel: 0.0004, bevelSegments: 1, material: mat)
                .transformed(Xform(translation: V3(x0, 0, P / 2 + 0.004)))
            both(v)
        }
        // Binding tape along the valance top and hem shadow line.
        both(HK.box(V3(W + 0.004, 0.02, 0.006), V3(0, valance - 0.01, P / 2 + 0.004), stripeA, r: 0.002, seg: 1))
        // Side cheeks: canvas triangles closing the ends.
        for sx: Float in [-1, 1] {
            var s = Surface(material: stripeA)
            let a = V3(sx * W / 2, yTop, zw), b = V3(sx * W / 2, yFront, P / 2), c = V3(sx * W / 2, yFront, zw + 0.02)
            let n = V3(sx, 0, 0)
            let i0 = s.add(a, n, V2(a.z, a.y)), i1 = s.add(b, n, V2(b.z, b.y)), i2 = s.add(c, n, V2(c.z, c.y))
            if sx > 0 { s.tri(i0, i1, i2) } else { s.tri(i0, i2, i1) }
            s.computeTangents()
            both(s); both(s.flipped())
        }

        // Frame: wall rail, brackets, end arms, ribs, front bar, wall-side support struts.
        let fm = frameMaterial, r: Float = 0.0125
        both(HK.cyl(r: r, len: W, at: V3(0, yTop - 0.02, zw + 0.03), axis: V3(1, 0, 0), mat: fm, seg: 12))
        both(HK.cyl(r: r, len: W, at: V3(0, yFront - 0.012, P / 2 - 0.01), axis: V3(1, 0, 0), mat: fm, seg: 12))
        for i in 0...ribs {
            let x = -W / 2 + W * Float(i) / Float(ribs) + (i == 0 ? 0.01 : i == ribs ? -0.01 : 0)
            let path = (0...6).map { k -> V3 in let p = canvas(x, Float(k) / 6); return p - V3(0, 0.016, 0) }
            both(HK.pipe(path, r: r * 0.85, sides: 8, mat: fm))
            // Wall bracket and diagonal strut under each rib.
            both(HK.box(V3(0.06, 0.14, 0.012), V3(x, yTop - 0.03, zw + 0.006), fm, r: 0.004))
            both(HK.box(V3(0.06, 0.12, 0.012), V3(x, yFront - 0.06, zw + 0.006), fm, r: 0.004))
            m.add(HK.pipe([V3(x, yFront - 0.06, zw + 0.012), V3(x, yTop + (yFront - yTop) * 0.55 - 0.03, zw + P * 0.55)], r: 0.009, sides: 8, mat: fm))
        }
        _ = rng.float()
        groundAO(&m, height: 0.1, floor: 0.8)
        return LODModel(levels: [m, lite], switchDistances: [10])
    }
}
