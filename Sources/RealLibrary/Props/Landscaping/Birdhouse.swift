import simd
import Foundation

public struct Birdhouse: RealAsset {
    public static let id = "birdhouse"
    public static let summary = "Cedar birdhouse on pole, 1.4 m: gabled roof, 38 mm entry hole, perch and copper cap."
    public static let tags = ["prop", "landscaping", "garden", "decor", "outdoor", "wood"]
    public static let budget = 5000
    public static let author = "realityhd"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let w = "wood.cedar-weathered"
        K.rod(&m, [V3(0, 0, 0), V3(0, 1.2, 0)], r: 0.022, w, sides: 10)
        K.box(&m, V3(0, 1.3, 0), V3(0.16, 0.2, 0.16), w)
        K.beam(&m, V3(-0.1, 1.42, 0), V3(0.01, 1.5, 0), 0.19, 0.012, w, up: V3(0, 1, 0))
        K.beam(&m, V3(0.1, 1.42, 0), V3(-0.01, 1.5, 0), 0.19, 0.012, w, up: V3(0, 1, 0))
        m.add(Prim.cylinder(radius: 0.019, height: 0.004, bevel: 0.001, segments: 16, material: "metal.shop-light-white"), Xform(translation: V3(0, 1.33, 0.081), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
        K.rod(&m, [V3(0, 1.26, 0.08), V3(0, 1.26, 0.13)], r: 0.005, w, sides: 6)
        K.box(&m, V3(0, 1.51, 0), V3(0.012, 0.012, 0.19), "metal.copper-patina")
        return K.finish(&m)
    }
}
