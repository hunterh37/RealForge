import simd
import Foundation

/// Black-eyed Susan, 0.7 m. Plant habit in `plan`, bloom shape and colors in `flower` (hex colors, petal count and rows,
/// petal size, cup and curl, center disc); both are plain values to override.
public struct BlackEyedSusan: RealAsset {
    public static let id = "black-eyed-susan"
    public static let summary = "Black-eyed Susan, 0.7 m: 10-16 hairy stems with yellow rays around dark domed centers."
    public static let tags = ["prop", "landscaping", "garden", "plant", "flower", "outdoor"]
    public static let budget = 9000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 30, elevation: 20)

    public var plan = FlowerPlan().with { $0.stems = 10...16; $0.height = 0.5...0.75; $0.spread = 0.18; $0.stemRadius = 0.003; $0.stemLeaves = 3...4; $0.basal = 0...0; $0.leafLength = 0.06...0.1; $0.leafBelly = 0.7; $0.leafWidth = 0.02; $0.facing = 0.4 }
    public var flower = FlowerStyle().with { $0.color = "F2B31A"; $0.center = "2A1A10"; $0.petals = 13; $0.length = 0.04; $0.width = 0.014; $0.tipWidth = 0.5; $0.lean = 1.45; $0.curl = 0.1; $0.centerRadius = 0.02; $0.centerDome = 0.7 }
    public init() {}

    public func build(seed: UInt64) -> LODModel { FlowerKit.lod(Self.id, plan, flower, seed: seed) }
}
