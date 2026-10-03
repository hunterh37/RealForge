import simd
import Foundation

public extension TreeSpecies {
    /// Weeping willow, ~12 m tall, ~13 m wide: short thick trunk, arching limbs, curtains of pendulous
    /// twigs 2 to 4 m long hanging close to the ground, narrow leaves 8 to 12 cm.
    static let willow = TreeSpecies(
        name: "willow", bark: "bark.willow", leaf: "leaf.willow", height: 12, trunkRadius: 0.42, trunkFraction: 0.26,
        trunkCurve: 9, trunkWobble: 0.02, flare: 0.5, flareLobes: 6,
        levels: [
            BranchLevel(density: 6, lengthRatio: 0.55, downAngle: 38, downAngleSpread: 10, curve: 20, gravity: 0.06, radiusRatio: 0.6, wobble: 0.06),
            BranchLevel(density: 2.2, span: 0.2...1, lengthRatio: 0.55, profile: .dome, downAngle: 55, downAngleSpread: 14, curve: 30, gravity: -0.1, radiusRatio: 0.45, wobble: 0.05),
            BranchLevel(density: 3.8, span: 0.1...1, lengthRatio: 1.0, downAngle: 50, downAngleSpread: 15, curve: 6, gravity: -3, radiusRatio: 0.35, wobble: 0.02),
        ],
        leaves: LeafParams(cardSize: V2(0.36, 0.85), density: 3.2, span: 0.05...1, orientation: .pendant, crownNormalBlend: 0.5),
        leafLevels: [0, 1, 2], barkTile: 0.6).with { $0.woodLevels = 1 }
}

/// Weeping willow, ~12 m: arching limbs and curtains of pendulous twigs with narrow leaves.
public struct WillowTree: RealAsset {
    public static let id = "willow-tree"
    public static let summary = "Weeping willow, ~12 m, arching limbs and curtains of long pendulous twigs with narrow leaves."
    public static let tags = ["nature", "tree", "deciduous", "water"]
    public static let budget = 45_000
    public static let author = "realforge"
    public var height: Float = 12
    public init() {}
    public func build(seed: UInt64) -> LODModel { Tree(TreeSpecies.willow.with { $0.height = height }).build(seed: seed) }
}
