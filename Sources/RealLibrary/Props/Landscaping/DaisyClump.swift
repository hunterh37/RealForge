import simd
import Foundation

/// Daisy clump, 0.45 m. Plant habit in `plan`, bloom shape and colors in `flower` (hex colors, petal count and rows,
/// petal size, cup and curl, center disc); both are plain values to override.
public struct DaisyClump: RealAsset {
    public static let id = "daisy-clump"
    public static let summary = "Shasta daisy clump, 0.45 m: 14-22 stems with white rays around yellow centers over dark leaves."
    public static let tags = ["prop", "landscaping", "garden", "plant", "flower", "outdoor"]
    public static let budget = 12000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 30, elevation: 20)

    public var plan = FlowerPlan().with { $0.stems = 14...22; $0.height = 0.3...0.45; $0.spread = 0.2; $0.stemRadius = 0.003; $0.stemLeaves = 0...0; $0.basal = 10...14; $0.leafLength = 0.06...0.1; $0.leafWidth = 0.02; $0.leafTip = 0.6; $0.facing = 0.3 }
    public var flower = FlowerStyle().with { $0.color = "F8F6F0"; $0.center = "F0C010"; $0.petals = 20; $0.length = 0.028; $0.width = 0.007; $0.tipWidth = 0.6; $0.lean = 1.5; $0.curl = 0; $0.centerRadius = 0.011; $0.centerDome = 0.6 }
    public init() {}

    public func build(seed: UInt64) -> LODModel { FlowerKit.lod(Self.id, plan, flower, seed: seed) }
}
