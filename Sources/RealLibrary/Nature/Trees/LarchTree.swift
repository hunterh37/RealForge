import simd
import Foundation

/// European larch (Larix decidua), ~20 m: open narrow cone, level branches with hanging branchlets,
/// soft light-green needle rosettes, reddish-brown scaly bark.
public struct LarchTree: RealAsset {
    public static let id = "larch-tree"
    public static let summary = "European larch, ~20 m: open cone of level branches with hanging branchlets and light-green needle rosettes, 3 LODs."
    public static let tags = ["nature", "tree", "conifer"]
    public static let budget = 45_000
    public static let author = "realityhd"

    /// Total height in meters.
    public var height: Float = 20
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var sp = TreeSpecies.larch
        sp.height = height
        return ConiferBuild.lods(sp, seed: seed, distances: [16, 45])
    }
}
