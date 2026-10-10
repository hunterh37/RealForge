import simd
import Foundation

/// Warehouse loading dock bay, 4.2 m wide, 3.0 m deep and 4.6 m tall: 1.2 m concrete platform, rubber bumpers, leveler plate, roll-up door, wall light.
public struct LoadingDock: RealAsset {
    public static let id = "loading-dock"
    public static let summary = "Loading dock bay, 4.2 m wide: concrete platform, rubber bumpers, steel leveler, ribbed roll-up door, wall light."
    public static let tags = ["prop", "industrial", "urban", "building", "concrete"]
    public static let budget = 3900
    public static let author = "hunterh37"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let W: Float = 4.2, D: Float = 3.0, ph: Float = 1.2
        K.box(&m, V3(0, ph / 2, 0), V3(W, ph, D), "concrete.rough", bevel: 0.015)
        K.box(&m, V3(0, ph + 0.01, 0.5), V3(W, 0.03, 2.0), "concrete.smooth", bevel: 0.006)
        K.box(&m, V3(0, 2.9, -D / 2 + 0.15), V3(W, 3.7 + ph - 0.4, 0.3), "brick.common", bevel: 0.01)
        K.box(&m, V3(0, ph + 1.65, -D / 2 + 0.32), V3(2.8, 3.1, 0.04), "metal.painted:2A2B2D", bevel: 0.008)
        var y: Float = ph + 0.15
        while y < ph + 3.1 {
            K.box(&m, V3(0, y, -D / 2 + 0.345), V3(2.7, 0.2, 0.025), "metal.painted:E6E3DB", bevel: 0.006)
            y += 0.22
        }
        for s: Float in [-1, 1] { K.box(&m, V3(s * 1.5, ph + 1.65, -D / 2 + 0.34), V3(0.12, 3.15, 0.07), "metal.galvanized", bevel: 0.006) }
        K.box(&m, V3(0, ph + 3.3, -D / 2 + 0.34), V3(3.1, 0.14, 0.2), "metal.galvanized", bevel: 0.006)
        K.box(&m, V3(0, ph + 0.05, D / 2 - 0.45), V3(2.3, 0.07, 2.0), "metal.steel", bevel: 0.01)
        K.box(&m, V3(0, ph + 0.1, D / 2 - 0.03), V3(2.3, 0.05, 0.06), "metal.painted:F2B705", bevel: 0.006)
        for s: Float in [-1, 1] {
            K.box(&m, V3(s * 1.45, ph - 0.35, D / 2 + 0.08), V3(0.3, 0.45, 0.16), "rubber.tire", bevel: 0.03)
            K.box(&m, V3(s * 1.45, ph - 0.1, D / 2 + 0.01), V3(0.34, 0.06, 0.04), "metal.painted:F2B705", bevel: 0.004)
        }
        K.rod(&m, [V3(0, ph + 3.7, -D / 2 + 0.3), V3(0, ph + 3.7, -D / 2 + 0.7), V3(0.5, ph + 3.7, -D / 2 + 0.7)], r: 0.02, "metal.galvanized", sides: 8)
        K.box(&m, V3(0.6, ph + 3.65, -D / 2 + 0.7), V3(0.34, 0.1, 0.16), "metal.painted:6B6F73", bevel: 0.015)
        K.box(&m, V3(0.6, ph + 3.595, -D / 2 + 0.7), V3(0.28, 0.02, 0.12), "emissive.warm", bevel: 0.004)
        return K.finish(&m, ao: 0.3)
    }
}
