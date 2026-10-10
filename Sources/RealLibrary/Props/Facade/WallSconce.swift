import simd
import Foundation

/// Wall sconce 0.3 m: bronze backplate, curved arm and frosted glass cylinder shade with a warm bulb.
public struct WallSconce: RealAsset {
    public static let id = "wall-sconce"
    public static let summary = "Wall sconce 0.3 m: bronze backplate, curved arm and frosted glass cylinder shade with a warm bulb."
    public static let tags = ["prop", "facade", "light", "metal"]
    public static let budget = 2400
    public static let author = "hunterh37"

    /// Primary material key.
    public var material: String = "metal.painted:3B2F25"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let material = self.material
        K.box(&m, V3(0, 0.15, -0.095), V3(0.08, 0.2, 0.012), material, bevel: 0.004)
        K.rod(&m, [V3(0, 0.15, -0.09), V3(0, 0.15, -0.04), V3(0, 0.18, 0.0), V3(0, 0.2, 0.0)], r: 0.008, material, sides: 8)
        cy(&m, 0.04, 0.02, V3(0, 0.19, -0.0), material, bevel: 0.003, seg: 20)
        m.add(Prim.lathe([V2(0.0, 0.0), V2(0.04, 0.0), V2(0.045, 0.1), V2(0.04, 0.2), V2(0.0, 0.2)], segments: 24, seamTile: 0.2, material: "glass.frosted"), Xform(translation: V3(0, 0.21, 0.0)))
        m.add(Prim.superellipsoid(V3(0.035, 0.06, 0.035), exponent: 2, subdivisions: 2, material: "emissive.warm"), Xform(translation: V3(0, 0.3, 0.0)))
        cy(&m, 0.045, 0.012, V3(0, 0.41, 0), material, bevel: 0.003, seg: 20)
        return K.finish(&m, ao: 0.05)
    }
}
