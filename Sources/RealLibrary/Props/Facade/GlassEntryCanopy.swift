import simd
import Foundation

/// Glass entry canopy 2.2 x 1.1 m: laminated glass pane on stainless spider fittings with rod tie-backs and wall plates.
public struct GlassEntryCanopy: RealAsset {
    public static let id = "glass-entry-canopy"
    public static let summary = "Glass entry canopy 2.2 x 1.1 m: laminated glass pane on stainless spider fittings with rod tie-backs and wall plates."
    public static let tags = ["prop", "facade", "door", "glass", "metal"]
    public static let budget = 3200
    public static let author = "hunterh37"

    /// Primary material key.
    public var material: String = "glass.pane"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let material = self.material
        let w: Float = 2.2, d: Float = 1.1, st = "metal.stainless"
        K.box(&m, V3(0, 0.5, 0.0), V3(w, 0.014, d), material, bevel: 0.002, rot: simd_quatf(degrees: 6, axis: V3(1, 0, 0)))
        K.box(&m, V3(0, 0.5, -d / 2 + 0.01), V3(w, 0.014, 0.08), "glass.frosted", bevel: 0.002)
        for x: Float in [-0.8, 0.8] {
            K.box(&m, V3(x, 0.6, -d / 2 - 0.0), V3(0.12, 0.12, 0.02), st, bevel: 0.004)
            rod(&m, V3(x, 0.6, -d / 2 + 0.01), V3(x, 0.5, d / 2 - 0.08), 0.01, st, sides: 8)
            rod(&m, V3(x, 0.95, -d / 2 + 0.01), V3(x, 0.5, d / 2 - 0.08), 0.007, st, sides: 8)
            K.box(&m, V3(x, 0.95, -d / 2), V3(0.08, 0.08, 0.02), st, bevel: 0.004)
            cy(&m, 0.022, 0.02, V3(x, 0.484, d / 2 - 0.08), st, bevel: 0.004, seg: 16)
            cy(&m, 0.022, 0.02, V3(x, 0.484, 0.0), st, bevel: 0.004, seg: 16)
        }
        for x: Float in [-0.8, 0.8] { cy(&m, 0.022, 0.02, V3(x, 0.514, -0.0), st, bevel: 0.004, seg: 16) }
        return K.finish(&m, ao: 0.05)
    }
}
