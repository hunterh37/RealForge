import simd
import Foundation

public extension TreeSpecies {
    /// European beech, ~18 m: smooth grey trunk running high into the crown, ascending limbs carrying
    /// flat horizontal sprays (layered crown), oval leaves 6 to 10 cm.
    static let beech = TreeSpecies(
        name: "beech", bark: "bark.beech", leaf: "leaf.beech", height: 18, trunkRadius: 0.36, trunkTipRatio: 0.3, trunkFraction: 0.42,
        trunkCurve: 3, trunkWobble: 0.01, flare: 0.55, flareLobes: 7,
        levels: [
            BranchLevel(density: 6, lengthRatio: 0.52, downAngle: 34, downAngleSpread: 10, curve: 24, gravity: 0.03, radiusRatio: 0.6, wobble: 0.04),
            BranchLevel(density: 1.3, span: 0.1...1, lengthRatio: 0.48, profile: .dome, downAngle: 72, downAngleSpread: 10, curve: 14, gravity: -0.04, radiusRatio: 0.45, wobble: 0.03, stubChance: 0.05),
            BranchLevel(density: 4.0, span: 0.25...1, lengthRatio: 0.38, profile: .tapered, downAngle: 55, downAngleSpread: 12, rotate: 180, curve: 10, gravity: 0.0, radiusRatio: 0.5, wobble: 0.03),
        ],
        leaves: LeafParams(cardSize: V2(0.42, 0.42), density: 9, span: 0.1...1, crownNormalBlend: 0.6, tipCluster: 0.3, sunBias: 0.6),
        barkTile: 0.6).with { $0.woodLevels = 1 }
}

/// European beech, ~18 m: smooth grey bark, high trunk, layered crown of flat leaf sprays.
public struct BeechTree: RealAsset {
    public static let id = "beech-tree"
    public static let summary = "European beech, ~18 m, smooth grey buttressed trunk, layered crown of flat leaf sprays."
    public static let tags = ["nature", "tree", "deciduous"]
    public static let budget = 45_000
    public static let author = "realityhd"
    public var height: Float = 18
    public init() {}
    public func build(seed: UInt64) -> LODModel { Tree(TreeSpecies.beech.with { $0.height = height }).build(seed: seed) }
}
