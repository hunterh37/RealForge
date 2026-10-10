import simd
import Foundation

/// Waste bin enclosure, 3.4 m wide, 1.8 m deep and 1.9 m tall: block walls, slatted timber gates, two wheeled bins inside.
public struct BinEnclosure: RealAsset {
    public static let id = "bin-enclosure"
    public static let summary = "Waste bin enclosure, 3.4 x 1.8 m: painted block walls, slatted timber gate doors, two wheeled bins with lids."
    public static let tags = ["prop", "street", "urban", "outdoor", "container", "concrete"]
    public static let budget = 5500
    public static let author = "hunterh37"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let W: Float = 3.4, D: Float = 1.8, H: Float = 1.9
        K.box(&m, V3(0, 0.04, 0), V3(W, 0.08, D), "concrete.rough", bevel: 0.006)
        K.box(&m, V3(0, 0.08 + H / 2, -D / 2 + 0.1), V3(W, H, 0.2), "concrete.smooth", bevel: 0.01)
        for s: Float in [-1, 1] {
            K.box(&m, V3(s * (W / 2 - 0.1), 0.08 + H / 2, 0), V3(0.2, H, D), "concrete.smooth", bevel: 0.01)
            K.box(&m, V3(s * (W / 2 - 0.1), 0.08 + H + 0.03, 0), V3(0.26, 0.06, D + 0.06), "stone.cap", bevel: 0.006)
        }
        K.box(&m, V3(0, 0.08 + H + 0.03, -D / 2 + 0.1), V3(W + 0.06, 0.06, 0.26), "stone.cap", bevel: 0.006)
        for g in 0..<2 {
            let gx = -0.82 + Float(g) * 1.64
            K.box(&m, V3(gx, 0.08 + 1.55, D / 2 - 0.08), V3(1.56, 0.05, 0.08), "wood.cedar-weathered", bevel: 0.006)
            K.box(&m, V3(gx, 0.08 + 0.18, D / 2 - 0.08), V3(1.56, 0.05, 0.08), "wood.cedar-weathered", bevel: 0.006)
            var y: Float = 0.3
            while y < 1.6 {
                K.box(&m, V3(gx, 0.08 + y, D / 2 - 0.04), V3(1.5, 0.12, 0.025 + rng.float(0...0.004)), "wood.cedar-weathered", bevel: 0.004)
                y += 0.16
            }
            let bc = g == 0 ? "plastic.matte:2C5E3A" : "plastic.matte:2B2D31"
            K.box(&m, V3(gx, 0.08 + 0.55, -0.1), V3(0.58, 0.95, 0.72), bc, bevel: 0.05)
            K.box(&m, V3(gx, 0.08 + 1.05, -0.1), V3(0.62, 0.05, 0.76), bc, bevel: 0.02)
            for x: Float in [-0.24, 0.24] { cy(&m, 0.1, 0.05, V3(gx + x, 0.08, -0.32), "rubber.tire", bevel: 0.01, seg: 14) }
        }
        return K.finish(&m, ao: 0.2)
    }
}
