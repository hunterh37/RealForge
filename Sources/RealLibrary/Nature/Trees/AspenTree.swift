import simd
import Foundation

public extension TreeSpecies {
    /// Quaking aspen, ~15 m tall, ~5 m wide: straight slender white-green trunk, self-pruned below with
    /// dark eye scars, short ascending branches in a narrow crown, round leaves 4 to 7 cm on flat stalks.
    static let aspen = TreeSpecies(
        name: "aspen", bark: "bark.aspen", leaf: "leaf.aspen", height: 15, trunkRadius: 0.17, trunkTipRatio: 0.05,
        trunkCurve: 4, trunkWobble: 0.01, flare: 0.2, flareLobes: 4,
        levels: [
            BranchLevel(density: 3.2, span: 0.45...0.985, lengthRatio: 0.22, profile: .tapered, downAngle: 42, downAngleSpread: 12, curve: 20, gravity: 0.12, radiusRatio: 0.38, wobble: 0.05, stubChance: 0.18),
            BranchLevel(density: 5.5, span: 0.15...1, lengthRatio: 0.5, downAngle: 40, downAngleSpread: 14, curve: 20, gravity: 0.0, radiusRatio: 0.5, wobble: 0.04),
        ],
        leaves: LeafParams(cardSize: V2(0.2, 0.22), density: 22, span: 0.1...1, crownNormalBlend: 0.6, tipCluster: 0.25, sunBias: 0.1),
        barkTile: 0.6).with { $0.woodLevels = 0; $0.roots = 0.5; $0.autumnLeaf = "leaf.aspen-gold" }
}

/// Quaking aspen, ~15 m: tall narrow crown, white-green bark with dark eye scars; `autumn` turns it gold.
public struct AspenTree: RealAsset {
    public static let id = "aspen-tree"
    public static let summary = "Quaking aspen, ~15 m, narrow crown, white-green bark with dark eye scars; autumn knob turns it gold."
    public static let tags = ["nature", "tree", "deciduous"]
    public static let budget = 45_000
    public static let author = "realityhd"
    public var height: Float = 15
    /// 0 = summer green, 1 = full autumn gold.
    public var autumn: Float = 0
    public init() {}
    public func build(seed: UInt64) -> LODModel { Tree(TreeSpecies.aspen.with { $0.height = height; $0.autumn = autumn }).build(seed: seed) }
}
