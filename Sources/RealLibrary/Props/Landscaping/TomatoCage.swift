import simd
import Foundation

/// 0.4 m cage diameter, 1.2 m tall.
public struct TomatoCage: RealAsset {
    public static let id = "tomato-cage"
    public static let summary = "Tomato cage with plant, 1.2 m: galvanized wire rings on six rods, soil mound, vine foliage and five ripe tomatoes."
    public static let tags = ["prop", "landscaping", "garden", "outdoor", "plant", "metal"]
    public static let budget = 6000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 35, elevation: 18)
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let wire = "metal.galvanized"
        for y in stride(from: Float(0.15), through: 1.15, by: 0.25) {
            m.add(Prim.torus(major: 0.2, minor: 0.0035, segments: 28, sides: 5, material: wire), Xform(translation: V3(0, y, 0)))
        }
        for k in 0..<6 {
            let a = Float(k) * .pi / 3
            K.rod(&m, [V3(cos(a) * 0.2, 0, sin(a) * 0.2), V3(cos(a) * 0.2, 1.2, sin(a) * 0.2)], r: 0.004, wire, sides: 5)
        }
        m.add(Prim.lathe([V2(0.3, 0), V2(0.26, 0.03), V2(0.12, 0.05), V2(0, 0.055)], segments: 24, seamTile: 0.3, material: "soil.potting"))
        K.rod(&m, [V3(0, 0.03, 0), V3(0.01, 0.6, 0), V3(0, 1.0, 0.01)], r: 0.01, "plant.stem")
        for i in 0..<9 {
            let y: Float = 0.2 + 0.1 * Float(i)
            m.add(Prim.superellipsoid(V3(0.15, 0.1, 0.15), exponent: 2, subdivisions: 4, material: "leaf.boxwood-mass"),
                  Xform(translation: V3(rng.float(-0.1...0.1), y, rng.float(-0.1...0.1))))
        }
        for i in 0..<5 {
            let a = Float(i) * 1.26
            m.add(Prim.superellipsoid(V3(0.065, 0.058, 0.065), exponent: 2, subdivisions: 4, material: "metal.painted:C0281C"),
                  Xform(translation: V3(cos(a) * 0.12, 0.45 + 0.13 * Float(i), sin(a) * 0.12)))
        }
        return K.finish(&m)
    }
}
