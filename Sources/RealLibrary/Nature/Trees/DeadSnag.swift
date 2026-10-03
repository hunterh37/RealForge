import simd
import Foundation

public extension TreeSpecies {
    /// Standing dead tree, ~9 m before the break: leaning trunk snapped at about 70 percent with a
    /// splintered top, a few bare limbs, many broken stubs, bark peeling off silver-grey wood.
    static let deadSnag = TreeSpecies(
        name: "dead-snag", bark: "bark.dead", leaf: "leaf.oak", height: 9, trunkRadius: 0.3, trunkTipRatio: 0.35,
        trunkCurve: 12, trunkWobble: 0.025, flare: 0.55, flareLobes: 5,
        levels: [
            BranchLevel(density: 2.2, span: 0.25...0.95, lengthRatio: 0.4, profile: .tapered, downAngle: 55, downAngleSpread: 18, curve: 35, gravity: 0.05, radiusRatio: 0.45, wobble: 0.08, stubChance: 0.35),
            BranchLevel(density: 2.6, span: 0.2...1, lengthRatio: 0.45, downAngle: 45, downAngleSpread: 18, curve: 30, gravity: 0.03, radiusRatio: 0.45, wobble: 0.08, stubChance: 0.3),
        ],
        leaves: LeafParams(cardSize: V2(0.3, 0.3), density: 0),
        barkTile: 0.5).with { $0.woodLevels = 2; $0.leafDensity = 0; $0.brokenTop = 0.72; $0.collar = 0.35 }
}

/// Dead snag: leafless standing dead tree with a broken top, broken stubs and peeling bark.
public struct DeadSnag: RealAsset {
    public static let id = "dead-snag"
    public static let summary = "Standing dead tree, ~6.5 m, splintered broken top, bare limbs and stubs, bark peeling off grey wood."
    public static let tags = ["nature", "tree", "wood"]
    public static let budget = 20_000
    public static let author = "realityhd"
    public var height: Float = 9
    /// Fraction of the trunk left standing below the break.
    public var breakAt: Float = 0.72
    public init() {}
    public func build(seed: UInt64) -> LODModel { Tree(TreeSpecies.deadSnag.with { $0.height = height; $0.brokenTop = breakAt }).build(seed: seed) }
}
