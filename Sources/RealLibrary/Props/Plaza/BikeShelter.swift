import simd
import Foundation

/// Covered bike shelter, 4.0 m long, 2.0 m deep and 2.4 m tall: four steel posts, tinted canopy, back panel, six inverted-U racks.
public struct BikeShelter: RealAsset {
    public static let id = "bike-shelter"
    public static let summary = "Covered bike shelter, 4 x 2 m: steel posts, sloped tinted canopy, glass back panel, six inverted-U racks."
    public static let tags = ["prop", "city", "street", "urban", "outdoor", "metal"]
    public static let budget = 1300
    public static let author = "hunterh37"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let steel = SK.paint(0x3A3F44), L: Float = 4.0, D: Float = 2.0
        K.box(&m, V3(0, 0.02, 0), V3(L + 0.2, 0.04, D + 0.2), "concrete.sidewalk", bevel: 0.006)
        for x: Float in [-L / 2, L / 2] {
            K.rod(&m, [V3(x, 0.04, -D / 2), V3(x, 2.5, -D / 2)], r: 0.04, steel, sides: 10)
            K.rod(&m, [V3(x, 0.04, D / 2), V3(x, 2.2, D / 2)], r: 0.04, steel, sides: 10)
            K.rod(&m, [V3(x, 2.2, D / 2), V3(x, 2.5, -D / 2)], r: 0.035, steel, sides: 10)
        }
        SK.sloped(&m, from: V2(D / 2 + 0.15, 2.2), to: V2(-D / 2 - 0.1, 2.52), width: L + 0.3, thick: 0.03, mat: "glass.tinted")
        K.box(&m, V3(0, 1.2, -D / 2), V3(L, 2.1, 0.02), "glass.tinted", bevel: 0.004)
        K.rod(&m, [V3(-L / 2, 1.2, -D / 2), V3(L / 2, 1.2, -D / 2)], r: 0.02, steel, sides: 8)
        for i in 0..<6 {
            let x = -1.65 + Float(i) * 0.66
            K.rod(&m, [V3(x, 0.04, -0.17), V3(x, 0.78, -0.17), V3(x, 0.9, -0.08), V3(x, 0.9, 0.08), V3(x, 0.78, 0.17), V3(x, 0.04, 0.17)], r: 0.018, "metal.galvanized", sides: 8)
        }
        return K.finish(&m, ao: 0.2)
    }
}
