import simd
import Foundation

/// Scrollwork balcony rail: a 1.6 x 1.0 m wrought-iron panel with a flat top rail, pickets, paired C
/// scrolls, a central S-scroll medallion with rosette and four leaf finials on the posts.
public struct ScrollworkBalconyRail: RealAsset {
    public static let id = "scrollwork-balcony-rail"
    public static let summary = "Wrought-iron scroll rail, 1.6 m: pickets, paired C-scrolls, central medallion, leaf finials."
    public static let tags = ["prop", "architecture", "facade", "trim", "metal", "urban"]
    public static let budget = 14_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 20, elevation: 8, distance: 3.0)

    public var width: Float = 1.6
    public var height: Float = 1.0
    public var iron: MaterialKey = "metal.wrought-iron"
    public var accent: MaterialKey = "metal.brass-aged"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let W = width, H = height, hw = W / 2, z: Float = 0.03
        FA.box(&m, V3(W, 0.04, 0.05), V3(0, H - 0.02, z), iron, r: 0.006)
        FA.box(&m, V3(W, 0.04, 0.04), V3(0, 0.02, z), iron, r: 0.004)
        FA.box(&m, V3(W - 0.1, 0.02, 0.025), V3(0, 0.12, z), iron, r: 0.003)
        FA.box(&m, V3(W - 0.1, 0.02, 0.025), V3(0, H - 0.14, z), iron, r: 0.003)
        for e: Float in [-1, 1] {
            FA.box(&m, V3(0.045, H, 0.045), V3(e * (hw - 0.0225), H / 2, z), iron, r: 0.004)
            FA.rod(&m, V3(e * (hw - 0.0225), H, z), V3(e * (hw - 0.0225), H + 0.08, z), r: 0.012, iron)
            m.add(Prim.superellipsoid(V3(0.05, 0.09, 0.05), exponent: 2, subdivisions: 4, material: accent), Xform(translation: V3(e * (hw - 0.0225), H + 0.11, z)))
        }
        let n = 13
        for i in 0..<n {
            let x = -hw + 0.1 + Float(i) * (W - 0.2) / Float(n - 1)
            if i % 3 != 1 { FA.rod(&m, V3(x, 0.04, z), V3(x, H - 0.04, z), r: 0.008, iron, sides: 8) }
        }
        // Paired C scrolls: two opposed rings joined by a short tangent bar, between the picket bays.
        for k in 0..<4 {
            let x = -hw + 0.25 + Float(k) * (W - 0.5) / 3
            let y = H * 0.5
            for (o, s) in [(-0.05, Float(1)), (0.05, Float(-1))] as [(Float, Float)] {
                m.add(Prim.torus(major: 0.06, minor: 0.007, segments: 20, sides: 6, material: iron),
                      Xform(translation: V3(x + o * s, y, z + 0.004), rotation: FA.q(90, FA.X)))
            }
            FA.rod(&m, V3(x, y - 0.06, z), V3(x, y + 0.06, z), r: 0.006, iron, sides: 6)
        }
        // Central S-scroll medallion.
        let c = V3(0, H * 0.5, z + 0.008)
        m.add(Prim.torus(major: 0.17, minor: 0.012, segments: 32, sides: 8, material: iron), Xform(translation: c, rotation: FA.q(90, FA.X)))
        m.add(Prim.torus(major: 0.09, minor: 0.008, segments: 24, sides: 6, material: iron), Xform(translation: c + V3(0, 0, 0.004), rotation: FA.q(90, FA.X)))
        for k in 0..<8 {
            let a = Float(k) * .pi / 4
            m.add(Prim.superellipsoid(V3(0.035, 0.06, 0.012), exponent: 2, subdivisions: 3, material: accent),
                  Xform(translation: c + V3(cos(a) * 0.05, sin(a) * 0.05, 0.012), rotation: FA.q(Float(k) * 45 - 90, FA.Z)))
        }
        FA.ball(&m, r: 0.022, at: c + V3(0, 0, 0.016), accent)
        FA.box(&m, V3(0.1, 0.18, 0.012), V3(-hw + 0.02, 0.15, 0.006), iron, r: 0.002)
        FA.box(&m, V3(0.1, 0.18, 0.012), V3(hw - 0.02, 0.15, 0.006), iron, r: 0.002)
        groundAO(&m, height: 0.1, floor: 0.82)
        return LODModel(FA.centerZ(m))
    }
}
