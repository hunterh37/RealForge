import simd
import Foundation

/// Balsam fir (Abies balsamea), ~15 m: narrow cone with a spire top, dense near-horizontal branches,
/// flat two-ranked needle sprays, smooth grey bark.
public struct FirTree: RealAsset {
    public static let id = "fir-tree"
    public static let summary = "Balsam fir, ~15 m: narrow spire-topped cone of dense flat needle sprays on smooth grey bark, 3 LODs."
    public static let tags = ["nature", "tree", "conifer"]
    public static let budget = 45_000
    public static let author = "realforge"

    /// Total height in meters.
    public var height: Float = 15
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var sp = TreeSpecies.fir
        sp.height = height
        return ConiferBuild.lods(sp, seed: seed) { m, _ in
            ConiferBuild.envelopeShade(&m, leaf: sp.leaf, blend: 0.35, up: 0.6)
        }
    }
}
