import simd
import Foundation

public extension TreeSpecies {
    /// Norway maple, ~14 m tall, ~11 m wide: short trunk forking into ascending limbs, dense rounded crown,
    /// five-lobed palmate leaves 10 to 15 cm across on long stalks.
    static let maple = TreeSpecies(
        name: "maple", bark: "bark.maple", leaf: "leaf.maple-norway", height: 14, trunkRadius: 0.3, trunkFraction: 0.34,
        trunkCurve: 5, trunkWobble: 0.015, flare: 0.5, flareLobes: 5,
        levels: [
            BranchLevel(density: 6, lengthRatio: 0.52, downAngle: 34, downAngleSpread: 10, curve: 26, gravity: 0.04, radiusRatio: 0.62, wobble: 0.05),
            BranchLevel(density: 2.2, span: 0.15...1, lengthRatio: 0.5, profile: .dome, downAngle: 48, downAngleSpread: 14, curve: 30, gravity: 0.0, radiusRatio: 0.5, wobble: 0.05, stubChance: 0.06),
            BranchLevel(density: 4.2, span: 0.2...1, lengthRatio: 0.34, profile: .tapered, downAngle: 42, downAngleSpread: 16, curve: 22, gravity: 0.05, radiusRatio: 0.55, wobble: 0.04),
        ],
        leaves: LeafParams(cardSize: V2(0.44, 0.44), density: 12, span: 0.15...1, crownNormalBlend: 0.72, tipCluster: 0.5, sunBias: 0.3),
        barkTile: 0.4).with { $0.woodLevels = 1; $0.autumnLeaf = "leaf.maple-red" }
}

/// Norway maple, ~14 m: dense rounded crown, palmate leaves; `autumn` turns the crown red and orange.
public struct MapleTree: RealAsset {
    public static let id = "maple-tree"
    public static let summary = "Norway maple, ~14 m, dense rounded crown, palmate leaves; autumn knob turns it red."
    public static let tags = ["nature", "tree", "deciduous"]
    public static let budget = 45_000
    public static let author = "realityhd"
    public var height: Float = 14
    /// 0 = summer green, 1 = full autumn red/orange.
    public var autumn: Float = 0
    /// Leaf card multiplier: 1 = full crown, lower for leaf fall.
    public var leafDensity: Float = 1
    public init() {}
    public func build(seed: UInt64) -> LODModel {
        Tree(TreeSpecies.maple.with { $0.height = height; $0.autumn = autumn; $0.leafDensity = leafDensity }).build(seed: seed)
    }
}
