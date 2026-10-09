import simd
import Foundation

public struct DogHouse: RealAsset {
    public static let id = "dog-house"
    public static let summary = "Wooden dog house, 0.9 x 1.0 x 0.8 m: gabled shingle roof, arched door, raised floor on feet."
    public static let tags = ["prop", "landscaping", "outdoor", "wood"]
    public static let budget = 8000
    public static let author = "realityhd"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let w = "wood.barn-red", t = "wood.barn-white"
        K.box(&m, V3(0, 0.05, 0), V3(0.9, 0.04, 1.0), "wood.cedar-weathered")
        for x: Float in [-0.4, 0.4] { for z: Float in [-0.45, 0.45] { K.box(&m, V3(x, 0.015, z), V3(0.06, 0.03, 0.06), "plastic.black") } }
        K.box(&m, V3(-0.43, 0.38, 0), V3(0.025, 0.6, 1.0), w); K.box(&m, V3(0.43, 0.38, 0), V3(0.025, 0.6, 1.0), w)
        K.box(&m, V3(0, 0.38, -0.49), V3(0.9, 0.6, 0.025), w)
        K.box(&m, V3(-0.28, 0.38, 0.49), V3(0.34, 0.6, 0.025), w); K.box(&m, V3(0.28, 0.38, 0.49), V3(0.34, 0.6, 0.025), w)
        K.box(&m, V3(0, 0.6, 0.49), V3(0.22, 0.2, 0.025), w)
        K.box(&m, V3(0, 0.69, 0.495), V3(0.9, 0.04, 0.03), t)
        K.beam(&m, V3(-0.55, 0.62, 0), V3(0, 0.98, 0), 1.1, 0.025, "roofing.shingle-granule", up: V3(0, 1, 0))
        K.beam(&m, V3(0.55, 0.62, 0), V3(0, 0.98, 0), 1.1, 0.025, "roofing.shingle-granule", up: V3(0, 1, 0))
        return K.finish(&m)
    }
}
