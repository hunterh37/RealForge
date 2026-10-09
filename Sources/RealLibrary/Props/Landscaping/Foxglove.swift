import simd
import Foundation

/// Foxglove, 1.2 m. Plant habit in `plan`, bloom shape and colors in `flower` (hex colors, petal count and rows,
/// petal size, cup and curl, center disc); both are plain values to override.
public struct Foxglove: RealAsset {
    public static let id = "foxglove"
    public static let summary = "Foxglove, 1.2 m: rosette of woolly leaves and 2-4 spires of pendant pink bells."
    public static let tags = ["prop", "landscaping", "garden", "plant", "flower", "outdoor"]
    public static let budget = 12000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 30, elevation: 20)

    public var plan = FlowerPlan().with { $0.habit = .spike; $0.stems = 2...4; $0.height = 1.0...1.4; $0.spread = 0.06; $0.stemRadius = 0.006; $0.stemLeaves = 2...3; $0.basal = 8...12; $0.leafLength = 0.25...0.35; $0.leafBelly = 0.7; $0.leafWidth = 0.06; $0.leafTip = 0.3; $0.florets = 12...18; $0.spikeStart = 0.4; $0.spikeRadius = 0.015; $0.facing = 0.6 }
    public var flower = FlowerStyle().with { $0.color = "C86AB0"; $0.petals = 5; $0.length = 0.045; $0.width = 0.022; $0.tipWidth = 0.7; $0.lean = 0.25; $0.curl = 0.7; $0.fold = -0.1 }
    public init() {}

    public func build(seed: UInt64) -> LODModel { FlowerKit.lod(Self.id, plan, flower, seed: seed) }
}
