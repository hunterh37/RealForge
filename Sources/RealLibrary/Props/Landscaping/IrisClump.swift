import simd
import Foundation

/// Iris clump, 0.9 m. Plant habit in `plan`, bloom shape and colors in `flower` (hex colors, petal count and rows,
/// petal size, cup and curl, center disc); both are plain values to override.
public struct IrisClump: RealAsset {
    public static let id = "iris-clump"
    public static let summary = "Bearded iris clump, 0.9 m: upright sword leaves and 5-8 tall stalks with violet blooms."
    public static let tags = ["prop", "landscaping", "garden", "plant", "flower", "outdoor"]
    public static let budget = 9000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 30, elevation: 20)

    public var plan = FlowerPlan().with { $0.stems = 5...8; $0.height = 0.7...0.9; $0.spread = 0.12; $0.stemRadius = 0.005; $0.stemLeaves = 1...2; $0.basal = 14...20; $0.leafLength = 0.4...0.6; $0.leafWidth = 0.03; $0.leafLean = 0.05...0.35; $0.facing = 0.35 }
    public var flower = FlowerStyle().with { $0.color = "6A4BC4"; $0.petals = 6; $0.length = 0.075; $0.width = 0.04; $0.tipWidth = 0.5; $0.lean = 0.9; $0.curl = 0.8; $0.fold = -0.15 }
    public init() {}

    public func build(seed: UInt64) -> LODModel { FlowerKit.lod(Self.id, plan, flower, seed: seed) }
}
