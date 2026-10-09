import simd
import Foundation

/// Hook 1.88 m tall, basket 0.38 m diameter hung at 1.2 m.
public struct HangingBasket: RealAsset {
    public static let id = "hanging-basket"
    public static let summary = "Hanging basket on a shepherd's hook, 1.9 m: black steel crook, three chains, coir basket with trailing foliage and blossoms."
    public static let tags = ["prop", "landscaping", "garden", "outdoor", "plant", "decor"]
    public static let budget = 6000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 35, elevation: 18)
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let iron = "metal.painted:1E1E20"
        var pts = [V3(0, 0, 0), V3(0, 1.7, 0)]
        pts += K.arc(V3(0.18, 1.7, 0), 0.18, 180, 0, n: 18).dropFirst()
        pts.append(V3(0.36, 1.62, 0))
        K.rod(&m, pts, r: 0.009, iron)
        let bx: Float = 0.36
        for k in 0..<3 {
            let a = Float(k) * 2.094 + 0.4
            K.rod(&m, [V3(bx, 1.63, 0), V3(bx + cos(a) * 0.17, 1.2, sin(a) * 0.17)], r: 0.0025, iron, sides: 5)
        }
        m.add(turned([(0, 1.0), (0.05, 1.0), (0.12, 1.04), (0.17, 1.12), (0.19, 1.2), (0.17, 1.2), (0, 1.1)], segments: 28, material: "sack.jute", seamTile: 0.1),
              Xform(translation: V3(bx, 0, 0)))
        m.add(Prim.superellipsoid(V3(0.46, 0.24, 0.46), exponent: 2, subdivisions: 6, material: "leaf.boxwood-mass"), Xform(translation: V3(bx, 1.27, 0)))
        for _ in 0..<9 {
            let a = rng.float(0...6.28), d = rng.float(0.03...0.17)
            m.add(Prim.superellipsoid(V3(0.045, 0.03, 0.045), exponent: 2, subdivisions: 3, material: "metal.painted:D9487A"),
                  Xform(translation: V3(bx + cos(a) * d, 1.37 - d * 0.3, sin(a) * d)))
        }
        return K.finish(&m)
    }
}
