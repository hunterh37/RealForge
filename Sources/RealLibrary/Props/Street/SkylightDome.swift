import simd
import Foundation

public struct SkylightDome: RealAsset {
    public static let id = "skylight-dome"
    public static let summary = "Roof skylight dome, 0.9 m square curb, aluminum flashing and acrylic bubble."
    public static let tags = ["prop", "urban", "glass", "outdoor"]
    public static let budget = 4000
    public init() {}
    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)

        bx(&m, V3(0.9,0.2,0.9), V3(0,0.1,0), "metal.aluminum-brushed", r: 0.01)
        m.add(Prim.superellipsoid(V3(0.82,0.4,0.82), exponent: 2.4, subdivisions: 14, material: "glass.clear"), Xform(translation: V3(0,0.28,0)))
        groundAO(&m, height: 0.2, floor: 0.6)
        return LODModel(m)
    }
}
