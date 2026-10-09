import simd
import Foundation

/// Daffodil clump, 0.45 m. Plant habit in `plan`, bloom shape and colors in `flower` (hex colors, petal count and rows,
/// petal size, cup and curl, center disc); both are plain values to override.
public struct DaffodilClump: RealAsset {
    public static let id = "daffodil-clump"
    public static let summary = "Daffodil clump, 0.45 m: 10-16 yellow six-petal daffodils with orange trumpets over narrow strap leaves, 0.45 m."
    public static let tags = ["prop", "landscaping", "garden", "plant", "flower", "outdoor"]
    public static let budget = 8000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 30, elevation: 20)

    public var plan = FlowerPlan().with { $0.stems = 10...16; $0.height = 0.35...0.45; $0.spread = 0.15; $0.stemRadius = 0.004; $0.stemLeaves = 0...0; $0.basal = 14...20; $0.leafLength = 0.3...0.4; $0.leafWidth = 0.015; $0.leafLean = 0.1...0.4; $0.facing = 0.6 }
    public var flower = FlowerStyle().with { $0.color = "FFE03A"; $0.center = "F2A21E"; $0.petals = 6; $0.length = 0.045; $0.width = 0.026; $0.tipWidth = 0.5; $0.lean = 1.35; $0.curl = 0.1; $0.centerRadius = 0.016; $0.centerDome = 1.4 }
    public init() {}

    public func build(seed: UInt64) -> LODModel { FlowerKit.lod(Self.id, plan, flower, seed: seed) }
}
