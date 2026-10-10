import simd
import Foundation

/// Street banner pole, 6 m: tapered steel pole, base plate, cross arm, vertical fabric banner on a top and bottom rail.
public struct StreetBannerPole: RealAsset {
    public static let id = "street-banner-pole"
    public static let summary = "Street banner pole, 6 m: tapered steel pole on a base plate with a cross arm and hanging fabric banner."
    public static let tags = ["prop", "urban", "street", "sign", "metal"]
    public static let budget = 2600
    public static let author = "hunterh37"

    /// Banner fabric material key.
    public var banner = "fabric.nylon"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        bx(&m, V3(0.4, 0.025, 0.4), V3(0, 0.0125, 0), "metal.galvanized", r: 0.004)
        for (x, z) in [(Float(-0.14), Float(-0.14)), (0.14, -0.14), (-0.14, 0.14), (0.14, 0.14)] { hexBolt(&m, at: V3(x, 0.025, z), normal: .up, size: 0.02, material: "metal.steel") }
        m.add(Prim.tube([V3(0, 0.02, 0), V3(0, 3, 0), V3(0, 6, 0)], radii: [0.09, 0.07, 0.05], sides: 20, seamTile: 0.4, material: "metal.painted:3A3F44"))
        rod(&m, V3(0, 5.5, 0), V3(0.95, 5.5, 0), 0.025, "metal.painted:3A3F44")
        rod(&m, V3(0, 3.3, 0), V3(0.95, 3.3, 0), 0.025, "metal.painted:3A3F44")
        rod(&m, V3(0, 5.15, 0), V3(0.7, 5.5, 0), 0.015, "metal.painted:3A3F44", sides: 8)
        let sway = rng.float(-0.01...0.01)
        bx(&m, V3(0.7, 2.0, 0.006), V3(0.62 + sway, 4.4, 0), MaterialKey(stringLiteral: banner), r: 0.002)
        bx(&m, V3(0.74, 0.03, 0.03), V3(0.62, 5.42, 0), "metal.steel", r: 0.005)
        bx(&m, V3(0.74, 0.03, 0.03), V3(0.62, 3.38, 0), "metal.steel", r: 0.005)
        return K.finish(&m, ao: 0.3)
    }
}
