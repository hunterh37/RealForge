import simd
import Foundation

public extension TreeSpecies {
    /// Mature English oak: short trunk splitting into heavy limbs, broad dome crown, lobed leaves.
    static let oak = TreeSpecies(
        name: "oak", bark: "bark.oak", leaf: "leaf.oak", height: 11, trunkRadius: 0.36, trunkFraction: 0.36,
        trunkCurve: 8, trunkWobble: 0.02, flare: 0.45, flareLobes: 6,
        levels: [
            BranchLevel(density: 5, lengthRatio: 0.52, downAngle: 38, downAngleSpread: 14, curve: 38, gravity: 0.02, radiusRatio: 0.68, wobble: 0.06),
            BranchLevel(density: 2.0, span: 0.18...1, lengthRatio: 0.48, profile: .dome, downAngle: 52, downAngleSpread: 15, curve: 40, gravity: -0.02, radiusRatio: 0.5, wobble: 0.05),
            BranchLevel(density: 3.4, span: 0.25...1, lengthRatio: 0.38, profile: .tapered, downAngle: 45, downAngleSpread: 18, curve: 25, gravity: 0.03, radiusRatio: 0.55, wobble: 0.04),
        ],
        leaves: LeafParams(cardSize: V2(0.5, 0.5), density: 6.5, span: 0.15...1, crownNormalBlend: 0.7),
        barkTile: 0.55).with { $0.woodLevels = 1 }

    /// Silver birch: slender white leader, ascending then weeping branches, small leaves.
    static let birch = TreeSpecies(
        name: "birch", bark: "bark.birch", leaf: "leaf.birch", height: 12, trunkRadius: 0.16, trunkTipRatio: 0.05,
        trunkCurve: 6, trunkWobble: 0.012, flare: 0.18, flareLobes: 4,
        levels: [
            BranchLevel(density: 3.0, span: 0.32...0.98, lengthRatio: 0.3, profile: .tapered, downAngle: 50, downAngleSpread: 12, curve: 28, gravity: 0.06, radiusRatio: 0.42, wobble: 0.05),
            BranchLevel(density: 4.2, span: 0.2...1, lengthRatio: 0.5, downAngle: 38, downAngleSpread: 15, curve: 25, gravity: -0.3, radiusRatio: 0.5, wobble: 0.04),
        ],
        leaves: LeafParams(cardSize: V2(0.34, 0.38), density: 8, span: 0.2...1, crownNormalBlend: 0.6),
        barkTile: 0.6).with { $0.woodLevels = 1 }

    /// Norway spruce: straight leader, whorled branches drooping then rising, dense needle sprigs.
    static let spruce = TreeSpecies(
        name: "spruce", bark: "bark.pine", leaf: "leaf.spruce", height: 14, trunkRadius: 0.24, trunkTipRatio: 0.03,
        trunkCurve: 2, trunkWobble: 0.006, flare: 0.3, flareLobes: 5,
        levels: [
            // Whorled main branches: out and slightly down, tips turning up.
            BranchLevel(density: 5.5, span: 0.08...0.985, lengthRatio: 0.3, profile: .conical, downAngle: 100, downAngleSpread: 8, curve: 6, gravity: 0.1, radiusRatio: 0.24, wobble: 0.025),
            // Side branchlets in the horizontal plane, slightly hanging.
            BranchLevel(density: 3.2, span: 0.15...0.95, lengthRatio: 0.32, downAngle: 58, downAngleSpread: 10, curve: 8, gravity: -0.15, radiusRatio: 0.45, wobble: 0.02),
        ],
        leaves: LeafParams(cardSize: V2(0.7, 0.9), density: 4.2, span: 0.0...1, orientation: .horizontal, crownNormalBlend: 0.5),
        leafLevels: [0, 1], barkTile: 0.45).with { $0.woodLevels = 0 }

    /// Multi-stem shrub.
    static let shrub = TreeSpecies(
        name: "shrub", bark: "bark.oak", leaf: "leaf.maple", height: 1.5, trunkRadius: 0.05, trunkFraction: 0.04,
        trunkCurve: 4, trunkWobble: 0.03, flare: 0,
        levels: [
            BranchLevel(density: 7, lengthRatio: 0.85, downAngle: 32, downAngleSpread: 14, curve: 30, gravity: 0.05, radiusRatio: 0.5, wobble: 0.06),
            BranchLevel(density: 7, span: 0.2...1, lengthRatio: 0.38, downAngle: 50, downAngleSpread: 15, curve: 25, gravity: 0, radiusRatio: 0.5, wobble: 0.05),
        ],
        leaves: LeafParams(cardSize: V2(0.34, 0.34), density: 7, span: 0.1...1, crownNormalBlend: 0.75),
        leafLevels: [0, 1], barkTile: 0.3)
}

/// Generic tree asset over a species. LOD0 hero (~20-35k tris), LOD1 (~6-10k), LOD2 (~1.5-3k).
public struct Tree: RealAsset {
    public static let id = "tree"
    public static let summary = "Recursive-branching tree with bark, alpha-card foliage, crown normals, wind weights, 3 LODs."
    public static let tags = ["nature", "tree"]
    public static let budget = 45_000

    public var species: TreeSpecies = .oak
    public var lodDistances: [Float] = [14, 40]
    public init() {}
    public init(_ species: TreeSpecies) { self.species = species }

    public func build(seed: UInt64) -> LODModel {
        let g = TreeGenerator(species: species, seed: seed)
        return LODModel(levels: [g.model(.lod0), g.model(.lod1), g.model(.lod2)], switchDistances: lodDistances)
    }
}

public struct OakTree: RealAsset {
    public static let id = "oak-tree"
    public static let summary = "Mature oak, ~11 m, broad dome crown."
    public static let tags = ["nature", "tree", "deciduous"]
    public static let budget = 45_000
    public var height: Float = 11
    public init() {}
    public func build(seed: UInt64) -> LODModel { Tree(TreeSpecies.oak.with { $0.height = height }).build(seed: seed) }
}

public struct BirchTree: RealAsset {
    public static let id = "birch-tree"
    public static let summary = "Silver birch, ~12 m, white bark, weeping twigs."
    public static let tags = ["nature", "tree", "deciduous"]
    public static let budget = 45_000
    public var height: Float = 12
    public init() {}
    public func build(seed: UInt64) -> LODModel { Tree(TreeSpecies.birch.with { $0.height = height }).build(seed: seed) }
}

public struct SpruceTree: RealAsset {
    public static let id = "spruce-tree"
    public static let summary = "Norway spruce, ~14 m, conical, needle sprigs."
    public static let tags = ["nature", "tree", "conifer"]
    public static let budget = 45_000
    public var height: Float = 14
    public init() {}
    public func build(seed: UInt64) -> LODModel { Tree(TreeSpecies.spruce.with { $0.height = height }).build(seed: seed) }
}

public struct Shrub: RealAsset {
    public static let id = "shrub"
    public static let summary = "Multi-stem leafy shrub, ~1.5 m."
    public static let tags = ["nature", "foliage"]
    public static let budget = 12_000
    public var height: Float = 1.5
    public init() {}
    public func build(seed: UInt64) -> LODModel {
        var t = Tree(TreeSpecies.shrub.with { $0.height = height })
        t.lodDistances = [8, 22]
        return t.build(seed: seed)
    }
}

public extension TreeSpecies {
    func with(_ edit: (inout TreeSpecies) -> Void) -> TreeSpecies { var c = self; edit(&c); return c }
}
