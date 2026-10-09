import simd
import Foundation

/// Tulip bed, 0.4 m. Plant habit in `plan`, bloom shape and colors in `flower` (hex colors, petal count and rows,
/// petal size, cup and curl, center disc); both are plain values to override.
public struct TulipBed: RealAsset {
    public static let id = "tulip-bed"
    public static let summary = "Tulip bed, 0.4 m: 14-20 upright cup-shaped red tulips on smooth stems over strap leaves, 0.4 m."
    public static let tags = ["prop", "landscaping", "garden", "plant", "flower", "outdoor"]
    public static let budget = 9000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 30, elevation: 20)

    public var plan = FlowerPlan().with { $0.stems = 14...20; $0.height = 0.3...0.45; $0.spread = 0.22; $0.stemRadius = 0.004; $0.stemLeaves = 2...3; $0.basal = 6...10; $0.leafLength = 0.15...0.25; $0.leafWidth = 0.04; $0.facing = 0.05 }
    public var flower = FlowerStyle().with { $0.color = "D81E3C"; $0.petals = 6; $0.length = 0.055; $0.width = 0.03; $0.tipWidth = 0.6; $0.lean = 0.25; $0.curl = 0.5; $0.fold = -0.25 }
    public init() {}

    public func build(seed: UInt64) -> LODModel { FlowerKit.lod(Self.id, plan, flower, seed: seed) }
}
