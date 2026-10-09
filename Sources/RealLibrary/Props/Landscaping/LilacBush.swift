import simd
import Foundation

/// Lilac bush, 1.9 m. Plant habit in `plan`, bloom shape and colors in `flower` (hex colors, petal count and rows,
/// petal size, cup and curl, center disc); both are plain values to override.
public struct LilacBush: RealAsset {
    public static let id = "lilac-bush"
    public static let summary = "Lilac bush, 1.9 m: 9-12 woody stems with heart-shaped leaves and conical panicles of violet four-petal florets."
    public static let tags = ["prop", "landscaping", "garden", "plant", "flower", "outdoor"]
    public static let budget = 15000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 30, elevation: 20)

    public var plan = FlowerPlan().with { $0.habit = .spike; $0.stems = 12...15; $0.height = 1.5...2.1; $0.spread = 0.45; $0.stemRadius = 0.014; $0.stemColor = "6B5A44"; $0.leafColor = "3F6B2E"; $0.stemLeaves = 18...24; $0.basal = 0...0; $0.leafLength = 0.08...0.12; $0.leafBelly = 0.7; $0.leafWidth = 0.06; $0.leafTip = 0.1; $0.leafLean = 0.8...1.3; $0.florets = 30...45; $0.spikeStart = 0.9; $0.spikeRadius = 0.045; $0.spikeTaper = 0.35; $0.facing = 0.85 }
    public var flower = FlowerStyle().with { $0.color = "B88AD0"; $0.petals = 4; $0.length = 0.017; $0.width = 0.011; $0.tipWidth = 0.5; $0.lean = 1.3; $0.curl = 0.1; $0.fold = 0 }
    public init() {}

    public func build(seed: UInt64) -> LODModel { FlowerKit.lod(Self.id, plan, flower, seed: seed) }
}
