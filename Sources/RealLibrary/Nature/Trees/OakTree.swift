import simd
import Foundation

public struct OakTree: RealAsset {
    public static let id = "oak-tree"
    public static let summary = "Mature oak, ~11 m, broad dome crown."
    public static let tags = ["nature", "tree", "deciduous"]
    public static let budget = 45_000
    public var height: Float = 11
    public init() {}
    public func build(seed: UInt64) -> LODModel { Tree(TreeSpecies.oak.with { $0.height = height }).build(seed: seed) }
}
