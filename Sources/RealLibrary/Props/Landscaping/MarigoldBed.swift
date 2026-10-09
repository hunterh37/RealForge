import simd
import Foundation

/// Marigold bed, 0.35 m. Plant habit in `plan`, bloom shape and colors in `flower` (hex colors, petal count and rows,
/// petal size, cup and curl, center disc); both are plain values to override.
public struct MarigoldBed: RealAsset {
    public static let id = "marigold-bed"
    public static let summary = "Marigold bed, 0.35 m: 14-22 compact stems with small leaves and orange pompon blooms."
    public static let tags = ["prop", "landscaping", "garden", "plant", "flower", "outdoor"]
    public static let budget = 14000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 30, elevation: 20)

    public var plan = FlowerPlan().with { $0.stems = 14...22; $0.height = 0.25...0.4; $0.spread = 0.2; $0.stemRadius = 0.003; $0.stemLeaves = 3...5; $0.basal = 0...0; $0.leafLength = 0.05...0.08; $0.leafBelly = 0.7; $0.leafWidth = 0.02; $0.leafTip = 0.2; $0.facing = 0.15 }
    public var flower = FlowerStyle().with { $0.color = "F29A1A"; $0.petals = 12; $0.rows = 4; $0.length = 0.028; $0.width = 0.016; $0.tipWidth = 0.8; $0.lean = 1.0; $0.curl = 0.3; $0.rowShrink = 0.85 }
    public init() {}

    public func build(seed: UInt64) -> LODModel { FlowerKit.lod(Self.id, plan, flower, seed: seed) }
}
