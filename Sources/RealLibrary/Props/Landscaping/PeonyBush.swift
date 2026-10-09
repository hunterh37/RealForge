import simd
import Foundation

/// Peony bush, 0.85 m. Plant habit in `plan`, bloom shape and colors in `flower` (hex colors, petal count and rows,
/// petal size, cup and curl, center disc); both are plain values to override.
public struct PeonyBush: RealAsset {
    public static let id = "peony-bush"
    public static let summary = "Peony bush, 0.85 m: 14-22 stems with lobed leaves and double pink blooms of five petal rows."
    public static let tags = ["prop", "landscaping", "garden", "plant", "flower", "outdoor"]
    public static let budget = 14000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 30, elevation: 20)

    public var plan = FlowerPlan().with { $0.stems = 14...22; $0.height = 0.6...0.85; $0.spread = 0.3; $0.stemRadius = 0.005; $0.stemLeaves = 7...10; $0.basal = 0...0; $0.leafLength = 0.1...0.16; $0.leafBelly = 0.7; $0.leafWidth = 0.05; $0.leafTip = 0.2; $0.facing = 0.3 }
    public var flower = FlowerStyle().with { $0.color = "F2A0B8"; $0.petals = 8; $0.rows = 3; $0.length = 0.06; $0.width = 0.045; $0.tipWidth = 0.8; $0.lean = 0.7; $0.curl = 0.9; $0.fold = -0.25; $0.rowShrink = 0.85; $0.rowLift = 0.1 }
    public init() {}

    public func build(seed: UInt64) -> LODModel { FlowerKit.lod(Self.id, plan, flower, seed: seed) }
}
