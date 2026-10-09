import simd
import Foundation

/// Zinnia bed, 0.7 m. Plant habit in `plan`, bloom shape and colors in `flower` (hex colors, petal count and rows,
/// petal size, cup and curl, center disc); both are plain values to override.
public struct ZinniaBed: RealAsset {
    public static let id = "zinnia-bed"
    public static let summary = "Zinnia bed, 0.7 m: 12-18 stems with opposite leaves and magenta layered blooms around yellow centers."
    public static let tags = ["prop", "landscaping", "garden", "plant", "flower", "outdoor"]
    public static let budget = 14000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 30, elevation: 20)

    public var plan = FlowerPlan().with { $0.stems = 12...18; $0.height = 0.5...0.75; $0.spread = 0.22; $0.stemRadius = 0.004; $0.stemLeaves = 4...6; $0.basal = 0...0; $0.leafLength = 0.08...0.12; $0.leafBelly = 0.7; $0.leafWidth = 0.04; $0.leafTip = 0.1; $0.facing = 0.5 }
    public var flower = FlowerStyle().with { $0.color = "F0457A"; $0.center = "E8C020"; $0.petals = 12; $0.rows = 3; $0.length = 0.04; $0.width = 0.016; $0.tipWidth = 0.6; $0.lean = 1.3; $0.curl = 0.15; $0.centerRadius = 0.014; $0.centerDome = 0.8 }
    public init() {}

    public func build(seed: UInt64) -> LODModel { FlowerKit.lod(Self.id, plan, flower, seed: seed) }
}
