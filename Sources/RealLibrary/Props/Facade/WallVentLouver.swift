import simd
import Foundation

/// Wall vent louver 0.5 x 0.5 m: framed galvanized grille with seven angled blades and insect mesh backing.
public struct WallVentLouver: RealAsset {
    public static let id = "wall-vent-louver"
    public static let summary = "Wall vent louver 0.5 x 0.5 m: framed galvanized grille with seven angled blades and insect mesh backing."
    public static let tags = ["prop", "facade", "building", "metal"]
    public static let budget = 1400
    public static let author = "hunterh37"

    /// Primary material key.
    public var material: String = "metal.galvanized"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let material = self.material
        let s: Float = 0.5
        for (c, sz) in [(V3(0, 0.02, 0), V3(s, 0.04, 0.06)), (V3(0, s - 0.02, 0), V3(s, 0.04, 0.06)), (V3(-s / 2 + 0.02, s / 2, 0), V3(0.04, s, 0.06)), (V3(s / 2 - 0.02, s / 2, 0), V3(0.04, s, 0.06))] { K.box(&m, c, sz, material, bevel: 0.004) }
        K.box(&m, V3(0, s / 2, -0.025), V3(s - 0.08, s - 0.08, 0.004), "fence.chainlink", bevel: 0.001)
        for i in 0..<7 { K.box(&m, V3(0, 0.07 + (s - 0.14) * Float(i) / 6, 0.005), V3(s - 0.08, 0.05, 0.006), material, bevel: 0.001, rot: simd_quatf(degrees: 35, axis: V3(1, 0, 0))) }
        return K.finish(&m, ao: 0.05)
    }
}
