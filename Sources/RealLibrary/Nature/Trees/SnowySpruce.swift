import simd
import Foundation

/// Norway spruce, ~14 m, after snowfall: the `spruce` species with snow-layer bark and needle materials
/// (white on up-facing sprays and branch tops).
public struct SnowySpruce: RealAsset {
    public static let id = "snowy-spruce"
    public static let summary = "Norway spruce, ~14 m, with snow lying on up-facing needle sprays and branches, 3 LODs."
    public static let tags = ["nature", "tree", "conifer", "snow"]
    public static let budget = 45_000
    public static let author = "realityhd"

    /// Total height in meters.
    public var height: Float = 14
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var sp = TreeSpecies.spruce
        sp.height = height
        sp.bark = "bark.pine-snow"
        sp.leaf = "leaf.spruce-snow"
        // Snow-laden sprays sit flatter and face up more.
        sp.leaves.crownNormalBlend = 0.35
        return ConiferBuild.lods(sp, seed: seed)
    }
}
