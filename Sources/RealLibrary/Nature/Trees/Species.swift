import simd
import Foundation

public extension TreeSpecies {
    /// Mature English oak, ~11 m tall and ~11 m wide: short buttressed trunk splitting into heavy
    /// spreading limbs, broad dome crown, lobed leaves (10 to 12 cm) clustered at the twig tips.
    static let oak = TreeSpecies(
        name: "oak", bark: "bark.oak", leaf: "leaf.oak", height: 11, trunkRadius: 0.38, trunkFraction: 0.32,
        trunkCurve: 8, trunkWobble: 0.02, flare: 0.75, flareLobes: 6,
        levels: [
            BranchLevel(density: 5, lengthRatio: 0.55, downAngle: 48, downAngleSpread: 10, curve: 22, gravity: 0.03, radiusRatio: 0.66, wobble: 0.07),
            BranchLevel(density: 2.4, span: 0.12...1, lengthRatio: 0.5, profile: .dome, downAngle: 50, downAngleSpread: 16, curve: 38, gravity: -0.03, radiusRatio: 0.5, wobble: 0.06, stubChance: 0.08),
            BranchLevel(density: 4.2, span: 0.2...1, lengthRatio: 0.34, profile: .tapered, downAngle: 45, downAngleSpread: 18, curve: 25, gravity: 0.05, radiusRatio: 0.55, wobble: 0.05),
        ],
        leaves: LeafParams(cardSize: V2(0.34, 0.34), density: 26, span: 0.1...1, crownNormalBlend: 0.7, tipCluster: 0.45, sunBias: 0.25),
        barkTile: 0.55).with { $0.woodLevels = 1 }

    /// Silver birch, ~12 m: slender white leader, ascending branches with long weeping twigs, small
    /// leaves (4 to 6 cm).
    static let birch = TreeSpecies(
        name: "birch", bark: "bark.birch", leaf: "leaf.birch", height: 12, trunkRadius: 0.16, trunkTipRatio: 0.05,
        trunkCurve: 6, trunkWobble: 0.012, flare: 0.25, flareLobes: 4,
        levels: [
            BranchLevel(density: 3.0, span: 0.32...0.98, lengthRatio: 0.3, profile: .tapered, downAngle: 48, downAngleSpread: 12, curve: 28, gravity: 0.06, radiusRatio: 0.42, wobble: 0.05, stubChance: 0.06),
            BranchLevel(density: 4.0, span: 0.2...1, lengthRatio: 0.55, downAngle: 38, downAngleSpread: 15, curve: 25, gravity: -0.35, radiusRatio: 0.5, wobble: 0.04),
        ],
        leaves: LeafParams(cardSize: V2(0.24, 0.27), density: 22, span: 0.15...1, crownNormalBlend: 0.6, tipCluster: 0.2, sunBias: 0.15),
        barkTile: 0.6).with { $0.woodLevels = 0; $0.roots = 0.6 }

    /// Norway spruce: straight leader, whorled branches drooping then rising, dense needle sprigs, dead
    /// stubs on the shaded lower trunk.
    static let spruce = TreeSpecies(
        name: "spruce", bark: "bark.pine", leaf: "leaf.spruce", height: 14, trunkRadius: 0.24, trunkTipRatio: 0.03,
        trunkCurve: 2, trunkWobble: 0.006, flare: 0.35, flareLobes: 5,
        levels: [
            // Whorled main branches: out and slightly down, tips turning up.
            BranchLevel(density: 5.5, span: 0.08...0.985, lengthRatio: 0.3, profile: .conical, downAngle: 100, downAngleSpread: 8, curve: 6, gravity: 0.1, radiusRatio: 0.24, wobble: 0.025, stubChance: 0.08),
            // Side branchlets in the horizontal plane, slightly hanging.
            BranchLevel(density: 3.2, span: 0.15...0.95, lengthRatio: 0.32, downAngle: 58, downAngleSpread: 10, curve: 8, gravity: -0.15, radiusRatio: 0.45, wobble: 0.02),
        ],
        leaves: LeafParams(cardSize: V2(0.7, 0.9), density: 4.2, span: 0.0...1, orientation: .horizontal, crownNormalBlend: 0.5),
        leafLevels: [0, 1], barkTile: 0.45).with { $0.woodLevels = 0; $0.roots = 0.7 }

    /// Multi-stem shrub, ~1.5 m.
    static let shrub = TreeSpecies(
        name: "shrub", bark: "bark.oak", leaf: "leaf.maple", height: 1.5, trunkRadius: 0.05, trunkFraction: 0.04,
        trunkCurve: 4, trunkWobble: 0.03, flare: 0,
        levels: [
            BranchLevel(density: 7, lengthRatio: 0.85, downAngle: 32, downAngleSpread: 14, curve: 30, gravity: 0.05, radiusRatio: 0.5, wobble: 0.06),
            BranchLevel(density: 7, span: 0.2...1, lengthRatio: 0.38, downAngle: 50, downAngleSpread: 15, curve: 25, gravity: 0, radiusRatio: 0.5, wobble: 0.05, stubChance: 0.05),
        ],
        leaves: LeafParams(cardSize: V2(0.26, 0.26), density: 14, span: 0.1...1, crownNormalBlend: 0.75, tipCluster: 0.3, sunBias: 0.2),
        leafLevels: [0, 1], barkTile: 0.3)
}

public extension TreeSpecies {
    func with(_ edit: (inout TreeSpecies) -> Void) -> TreeSpecies { var c = self; edit(&c); return c }
}
