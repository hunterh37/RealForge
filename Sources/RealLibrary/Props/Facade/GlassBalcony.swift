import simd
import Foundation

/// Cantilever balcony 2.0 x 1.0 m: concrete slab, frameless glass guard on steel standoffs and steel handrail.
public struct GlassBalcony: RealAsset {
    public static let id = "glass-balcony"
    public static let summary = "Cantilever balcony 2.0 x 1.0 m: concrete slab, frameless glass guard on steel standoffs and steel handrail."
    public static let tags = ["prop", "facade", "architecture", "glass", "concrete"]
    public static let budget = 3800
    public static let author = "hunterh37"

    /// Primary material key.
    public var material: String = "concrete.smooth"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let material = self.material
        let w: Float = 2.0, d: Float = 1.0
        K.box(&m, V3(0, 0.075, 0), V3(w, 0.15, d), material, bevel: 0.006)
        K.box(&m, V3(0, 0.152, 0), V3(w - 0.02, 0.006, d - 0.02), "concrete.rough", bevel: 0.001)
        for (c, s) in [(V3(0, 0.65, d / 2 - 0.05), V3(w - 0.1, 0.95, 0.012)), (V3(-w / 2 + 0.05, 0.65, 0), V3(0.012, 0.95, d - 0.1)), (V3(w / 2 - 0.05, 0.65, 0), V3(0.012, 0.95, d - 0.1))] {
            K.box(&m, c, s, "glass.pane", bevel: 0.002)
        }
        for x: Float in [-0.85, -0.3, 0.3, 0.85] { cy(&m, 0.014, 0.05, V3(x, 0.15, d / 2 - 0.035), "metal.steel", bevel: 0.002, seg: 12) }
        K.rod(&m, [V3(-w / 2 + 0.05, 1.12, -d / 2 + 0.05), V3(-w / 2 + 0.05, 1.12, d / 2 - 0.05), V3(w / 2 - 0.05, 1.12, d / 2 - 0.05), V3(w / 2 - 0.05, 1.12, -d / 2 + 0.05)], r: 0.02, "metal.steel", sides: 10)
        return K.finish(&m, ao: 0.05)
    }
}
