import simd
import Foundation

public struct GardenKneeler: RealAsset {
    public static let id = "garden-kneeler"
    public static let summary = "Garden kneeler bench, 0.6 x 0.28 x 0.5 m: foam kneeling pad, steel arm rails that flip into a seat."
    public static let tags = ["prop", "landscaping", "garden", "outdoor", "tool", "metal"]
    public static let budget = 5000
    public static let author = "realityhd"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let g = "metal.painted:2E6B34"
        m.add(Prim.superellipsoid(V3(0.55, 0.05, 0.28), exponent: 4, subdivisions: 5, material: "foam.liner"), Xform(translation: V3(0, 0.235, 0)))
        K.box(&m, V3(0, 0.205, 0), V3(0.56, 0.015, 0.3), g)
        for s: Float in [-1, 1] {
            K.rod(&m, [V3(s * 0.27, 0.2, 0.12), V3(s * 0.27, 0.0, 0.12)], r: 0.011, g, sides: 8)
            K.rod(&m, [V3(s * 0.27, 0.2, -0.12), V3(s * 0.27, 0.0, -0.12)], r: 0.011, g, sides: 8)
            K.rod(&m, [V3(s * 0.27, 0.0, 0.12), V3(s * 0.27, 0.0, -0.12)], r: 0.011, g, sides: 8)
            K.rod(&m, [V3(s * 0.27, 0.2, 0.12), V3(s * 0.27, 0.4, 0.14), V3(s * 0.27, 0.45, -0.1), V3(s * 0.27, 0.2, -0.12)], r: 0.011, g, sides: 8)
        }
        K.rod(&m, [V3(-0.27, 0.45, 0), V3(0.27, 0.45, 0)], r: 0.014, "plastic.black", sides: 8)
        return K.finish(&m)
    }
}
