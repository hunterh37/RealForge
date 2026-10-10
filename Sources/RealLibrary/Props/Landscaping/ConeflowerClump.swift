import simd
import Foundation

/// Coneflower clump, 0.8 m. Plant habit in `plan`, bloom shape and colors in `flower` (hex colors, petal count and rows,
/// petal size, cup and curl, center disc); both are plain values to override.
public struct ConeflowerClump: RealAsset {
    public static let id = "coneflower-clump"
    public static let summary = "Purple coneflower clump, 0.8 m: 8-12 stems with drooping pink-purple rays around orange spiky cones."
    public static let tags = ["prop", "landscaping", "garden", "plant", "flower", "outdoor"]
    public static let budget = 9000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 30, elevation: 20)

    public var plan = FlowerPlan().with { $0.stems = 8...12; $0.height = 0.6...0.9; $0.spread = 0.15; $0.stemRadius = 0.0035; $0.stemLeaves = 2...3; $0.basal = 8...12; $0.leafLength = 0.12...0.18; $0.leafBelly = 0.7; $0.leafWidth = 0.035; $0.facing = 0.2 }
    public var flower = FlowerStyle().with { $0.color = "D9609A"; $0.center = "B5541C"; $0.petals = 12; $0.length = 0.06; $0.width = 0.014; $0.tipWidth = 0.5; $0.lean = 2.0; $0.curl = 0.4; $0.centerRadius = 0.026; $0.centerDome = 1.2 }
    public init() {}

    public func build(seed: UInt64) -> LODModel { FlowerKit.lod(Self.id, plan, flower, seed: seed) }
}
