import simd
import Foundation

public struct SpruceTree: RealAsset {
    public static let id = "spruce-tree"
    public static let summary = "Norway spruce, ~14 m, conical, needle sprigs."
    public static let tags = ["nature", "tree", "conifer"]
    public static let budget = 45_000
    public var height: Float = 14
    public init() {}
    public func build(seed: UInt64) -> LODModel { Tree(TreeSpecies.spruce.with { $0.height = height }).build(seed: seed) }
}
