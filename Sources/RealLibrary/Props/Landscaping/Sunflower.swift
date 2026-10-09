import simd
import Foundation

/// Sunflower, 1.8 m. Plant habit in `plan`, bloom shape and colors in `flower` (hex colors, petal count and rows,
/// petal size, cup and curl, center disc); both are plain values to override.
public struct Sunflower: RealAsset {
    public static let id = "sunflower"
    public static let summary = "Sunflower, 1.8 m: 1-3 stout stalks with broad heart-shaped leaves and 25 cm heads, two rows of yellow rays around a brown disc."
    public static let tags = ["prop", "landscaping", "garden", "plant", "flower", "outdoor"]
    public static let budget = 9000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 30, elevation: 20)

    public var plan = FlowerPlan().with { $0.stems = 1...3; $0.height = 1.5...2.1; $0.spread = 0.08; $0.stemRadius = 0.011; $0.stemLeaves = 7...10; $0.basal = 0...0; $0.leafLength = 0.22...0.32; $0.leafBelly = 0.7; $0.leafWidth = 0.11; $0.leafTip = 0.15; $0.leafLean = 0.9...1.4; $0.facing = 0.85 }
    public var flower = FlowerStyle().with { $0.color = "FFC81E"; $0.center = "3A2410"; $0.petals = 21; $0.rows = 2; $0.length = 0.1; $0.width = 0.026; $0.tipWidth = 0.3; $0.lean = 1.45; $0.curl = 0.1; $0.fold = -0.05; $0.centerRadius = 0.075; $0.centerDome = 0.3 }
    public init() {}

    public func build(seed: UInt64) -> LODModel { FlowerKit.lod(Self.id, plan, flower, seed: seed) }
}
