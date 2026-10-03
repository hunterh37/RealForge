import simd
import Foundation

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
