import simd
import Foundation

/// 1.0 m by 0.2 m by 0.17 m box on two bracket arms.
public struct WindowBox: RealAsset {
    public static let id = "window-box"
    public static let summary = "Window box planter, 0.3 m: 1.0 m cedar box with soil, mounded foliage, blossoms and two steel brackets."
    public static let tags = ["prop", "landscaping", "garden", "outdoor", "container", "wood", "plant"]
    public static let budget = 5000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 35, elevation: 18)
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let wood = "wood.cedar-weathered"
        K.box(&m, V3(0, 0.085, 0.091), V3(1.0, 0.17, 0.018), wood)
        K.box(&m, V3(0, 0.085, -0.091), V3(1.0, 0.17, 0.018), wood)
        for s: Float in [-1, 1] { K.box(&m, V3(s * 0.491, 0.085, 0), V3(0.018, 0.17, 0.2), wood) }
        K.box(&m, V3(0, 0.009, 0), V3(0.96, 0.018, 0.17), wood)
        K.box(&m, V3(0, 0.14, 0), V3(0.97, 0.02, 0.17), "soil.potting")
        for i in 0..<5 {
            let x: Float = -0.4 + 0.2 * Float(i)
            m.add(Prim.superellipsoid(V3(rng.float(0.2...0.26), 0.15, 0.19), exponent: 2, subdivisions: 5, material: "leaf.boxwood-mass"), Xform(translation: V3(x, 0.2, 0)))
        }
        for _ in 0..<14 {
            m.add(Prim.superellipsoid(V3(0.04, 0.03, 0.04), exponent: 2, subdivisions: 3, material: "metal.painted:E8B923"),
                  Xform(translation: V3(rng.float(-0.45...0.45), rng.float(0.26...0.32), rng.float(-0.08...0.08))))
        }
        for s: Float in [-1, 1] {
            K.box(&m, V3(s * 0.3, -0.012, 0), V3(0.025, 0.012, 0.26), "metal.painted:2A2A2A", bevel: 0.002)
            K.box(&m, V3(s * 0.3, -0.06, -0.125), V3(0.025, 0.1, 0.012), "metal.painted:2A2A2A", bevel: 0.002)
        }
        return K.finish(&m)
    }
}
