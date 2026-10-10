import simd
import Foundation

/// Fuel station canopy, 12 m by 7 m and 5.5 m tall: flat white roof slab with accent fascia, four columns, lit underside, two pump islands.
public struct FuelCanopy: RealAsset {
    public static let id = "fuel-canopy"
    public static let summary = "Fuel station canopy, 12 x 7 m: white roof slab with colored fascia, four round columns, lit soffit, two pump islands."
    public static let tags = ["prop", "city", "road", "street", "urban", "metal"]
    public static let budget = 5900
    public static let author = "hunterh37"

    /// Fascia band paint, sRGB hex.
    public var accent: UInt32 = 0xC8102E
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let white = SK.paint(0xF4F4F0)
        K.box(&m, V3(0, 5.1, 0), V3(12, 0.6, 7), white, bevel: 0.03)
        K.box(&m, V3(0, 5.1, 0), V3(12.04, 0.2, 7.04), SK.paint(accent), bevel: 0.01)
        K.box(&m, V3(0, 4.78, 0), V3(11.6, 0.03, 6.6), "emissive.panel", bevel: 0.004)
        for (x, z): (Float, Float) in [(-4.5, -2.0), (4.5, -2.0), (-4.5, 2.0), (4.5, 2.0)] {
            cy(&m, 0.25, 4.8, V3(x, 0, z), "metal.painted:EDEDE8", bevel: 0.01, seg: 24)
            cy(&m, 0.3, 0.12, V3(x, 0, z), "concrete.rough", bevel: 0.01, seg: 24)
        }
        for x: Float in [-2.25, 2.25] {
            K.box(&m, V3(x, 0.09, 0), V3(1.2, 0.18, 4.6), "concrete.smooth", bevel: 0.015)
            for z: Float in [-1.9, 1.9] { cy(&m, 0.07, 0.9, V3(x, 0.18, z), "metal.painted:C8102E", bevel: 0.01, seg: 12) }
        }
        return K.finish(&m, ao: 0.3)
    }
}
