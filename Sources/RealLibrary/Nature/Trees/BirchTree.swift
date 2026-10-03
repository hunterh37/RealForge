import simd
import Foundation

public struct BirchTree: RealAsset {
    public static let id = "birch-tree"
    public static let summary = "Silver birch, ~12 m, white bark, weeping twigs."
    public static let tags = ["nature", "tree", "deciduous"]
    public static let budget = 45_000
    public var height: Float = 12
    public init() {}
    public func build(seed: UInt64) -> LODModel { Tree(TreeSpecies.birch.with { $0.height = height }).build(seed: seed) }
}
