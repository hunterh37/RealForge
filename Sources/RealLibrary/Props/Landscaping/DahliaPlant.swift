import simd
import Foundation

/// Dahlia plant, 1.1 m. Plant habit in `plan`, bloom shape and colors in `flower` (hex colors, petal count and rows,
/// petal size, cup and curl, center disc); both are plain values to override.
public struct DahliaPlant: RealAsset {
    public static let id = "dahlia-plant"
    public static let summary = "Dahlia plant, 1.1 m: 4-7 stalks with serrated leaves and orange dinner-plate blooms of five petal rows."
    public static let tags = ["prop", "landscaping", "garden", "plant", "flower", "outdoor"]
    public static let budget = 14000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 30, elevation: 20)

    public var plan = FlowerPlan().with { $0.stems = 4...7; $0.height = 0.9...1.3; $0.spread = 0.1; $0.stemRadius = 0.007; $0.stemLeaves = 6...8; $0.basal = 0...0; $0.leafLength = 0.12...0.18; $0.leafBelly = 0.7; $0.leafWidth = 0.06; $0.leafTip = 0.15; $0.facing = 0.5 }
    public var flower = FlowerStyle().with { $0.color = "E2552B"; $0.petals = 14; $0.rows = 5; $0.length = 0.055; $0.width = 0.018; $0.tipWidth = 0.5; $0.lean = 1.2; $0.curl = 0.2; $0.fold = -0.05; $0.rowShrink = 0.88; $0.rowLift = 0.2 }
    public init() {}

    public func build(seed: UInt64) -> LODModel { FlowerKit.lod(Self.id, plan, flower, seed: seed) }
}
