import simd
import Foundation

public extension TreeSpecies {
    /// Japanese maple, ~5 m tall, ~6 m wide: low fork into sinuous spreading limbs, flat layered tiers,
    /// deeply cut seven-lobed red leaves 5 to 7 cm across.
    static let japaneseMaple = TreeSpecies(
        name: "japanese-maple", bark: "bark.japanese-maple", leaf: "leaf.japanese-maple", height: 5, trunkRadius: 0.13, trunkFraction: 0.24,
        trunkCurve: 12, trunkWobble: 0.03, flare: 0.35, flareLobes: 5,
        levels: [
            BranchLevel(density: 6, lengthRatio: 0.6, downAngle: 34, downAngleSpread: 10, curve: 30, gravity: 0.06, radiusRatio: 0.66, wobble: 0.08),
            BranchLevel(density: 3.4, span: 0.3...1, lengthRatio: 0.5, profile: .dome, downAngle: 66, downAngleSpread: 12, curve: 20, gravity: -0.05, radiusRatio: 0.5, wobble: 0.05),
            BranchLevel(density: 6, span: 0.2...1, lengthRatio: 0.4, profile: .tapered, downAngle: 50, downAngleSpread: 14, rotate: 180, curve: 15, gravity: 0.0, radiusRatio: 0.5, wobble: 0.04),
        ],
        leaves: LeafParams(cardSize: V2(0.28, 0.28), density: 32, span: 0.1...1, crownNormalBlend: 0.55, tipCluster: 0.4, sunBias: 0.65),
        barkTile: 0.35).with { $0.woodLevels = 1; $0.roots = 0.6 }
}

/// Japanese maple, ~5 m: small layered crown of red, deeply cut palmate leaves.
public struct JapaneseMaple: RealAsset {
    public static let id = "japanese-maple"
    public static let summary = "Japanese maple, ~5 m, low-forked sinuous limbs, layered crown of deep red palmate leaves."
    public static let tags = ["nature", "tree", "deciduous", "garden"]
    public static let budget = 40_000
    public static let author = "realforge"
    public static let preview = PreviewHint(azimuth: 35, elevation: 14)
    public var height: Float = 5
    public init() {}
    public func build(seed: UInt64) -> LODModel {
        var t = Tree(TreeSpecies.japaneseMaple.with { $0.height = height })
        t.lodDistances = [10, 30]
        return t.build(seed: seed)
    }
}
