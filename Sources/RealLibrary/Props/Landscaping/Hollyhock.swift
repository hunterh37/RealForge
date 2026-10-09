import simd
import Foundation

/// Hollyhock, 1.8 m. Plant habit in `plan`, bloom shape and colors in `flower` (hex colors, petal count and rows,
/// petal size, cup and curl, center disc); both are plain values to override.
public struct Hollyhock: RealAsset {
    public static let id = "hollyhock"
    public static let summary = "Hollyhock, 1.8 m: 2-3 tall stalks with rounded leaves and pink saucer blooms facing outward."
    public static let tags = ["prop", "landscaping", "garden", "plant", "flower", "outdoor"]
    public static let budget = 12000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 30, elevation: 20)

    public var plan = FlowerPlan().with { $0.habit = .spike; $0.stems = 2...3; $0.height = 1.6...2.0; $0.spread = 0.08; $0.stemRadius = 0.008; $0.stemLeaves = 6...8; $0.basal = 8...12; $0.leafLength = 0.2...0.3; $0.leafBelly = 0.7; $0.leafWidth = 0.12; $0.leafTip = 0.2; $0.florets = 12...16; $0.spikeStart = 0.3; $0.spikeRadius = 0.03; $0.spikeTaper = 0.5; $0.facing = 0.9 }
    public var flower = FlowerStyle().with { $0.color = "F0B8D0"; $0.center = "F2E070"; $0.petals = 5; $0.length = 0.045; $0.width = 0.045; $0.tipWidth = 0.9; $0.lean = 1.2; $0.curl = 0.2; $0.fold = -0.2; $0.centerRadius = 0.01 }
    public init() {}

    public func build(seed: UInt64) -> LODModel { FlowerKit.lod(Self.id, plan, flower, seed: seed) }
}
