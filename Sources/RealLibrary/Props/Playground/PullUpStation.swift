import simd
import Foundation

/// Outdoor fitness station, 2.4 m wide: two posts with a high pull-up bar, a low bar and a dip frame between.
public struct PullUpStation: RealAsset {
    public static let id = "pull-up-station"
    public static let summary = "Outdoor fitness station, 2.4 m: steel posts with high pull-up bar, low bar and parallel dip bars."
    public static let tags = ["prop", "park", "outdoor", "sports", "metal"]
    public static let budget = 1900
    public static let author = "hunterh37"

    /// Pull-up bar height in meters.
    public var barHeight: Float = 2.3
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let W: Float = 2.4, mat: MaterialKey = "metal.painted:3A3F44"
        for x: Float in [-W / 2, W / 2] {
            rod(&m, V3(x, 0, 0), V3(x, barHeight + 0.1, 0), 0.05, mat, sides: 14)
            cy(&m, 0.12, 0.02, V3(x, 0, 0), "metal.galvanized", bevel: 0.004)
        }
        rod(&m, V3(-W / 2, barHeight, 0), V3(W / 2, barHeight, 0), 0.02, "metal.stainless", sides: 12)
        rod(&m, V3(-W / 2, 1.3, 0), V3(W / 2, 1.3, 0), 0.02, "metal.stainless", sides: 12)
        for z: Float in [-0.25, 0.25] {
            rod(&m, V3(-0.4, 1.05, z), V3(0.4, 1.05, z), 0.02, "metal.stainless", sides: 12)
            for x: Float in [-0.4, 0.4] { rod(&m, V3(x, 0, z), V3(x, 1.05, z), 0.03, mat, sides: 12) }
        }
        return K.finish(&m, ao: 0.2)
    }
}
