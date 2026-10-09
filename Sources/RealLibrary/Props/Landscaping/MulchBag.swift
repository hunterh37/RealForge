import simd
import Foundation

public struct MulchBag: RealAsset {
    public static let id = "mulch-bag"
    public static let summary = "Bagged mulch, 0.76 x 0.45 x 0.2 m: sealed polyethylene bag with tan label band and heat-seal ends."
    public static let tags = ["prop", "landscaping", "outdoor", "garden"]
    public static let budget = 3000
    public static let author = "realityhd"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        m.add(Prim.superellipsoid(V3(0.7, 0.2, 0.44), exponent: 3, subdivisions: 6, material: "plastic.matte"), Xform(translation: V3(0, 0.1, 0)))
        K.box(&m, V3(0, 0.12, 0.2), V3(0.44, 0.12, 0.012), "plastic.orange", bevel: 0.002)
        for s: Float in [-1, 1] { K.box(&m, V3(s * 0.36, 0.1, 0), V3(0.025, 0.04, 0.4), "plastic.matte", bevel: 0.004) }
        m.add(Prim.superellipsoid(V3(0.3, 0.05, 0.2), exponent: 2, subdivisions: 4, material: "soil.potting"), Xform(translation: V3(0.1, 0.205, 0)))
        return K.finish(&m)
    }
}
