import simd
import Foundation

/// Italian cypress (Cupressus sempervirens 'Stricta'), ~18 m tall and under 2 m wide: a dense column of
/// ascending branches clothed in scale foliage, fibrous grey-brown bark.
public struct CypressTree: RealAsset {
    public static let id = "cypress-tree"
    public static let summary = "Italian cypress, ~18 m by 1.8 m: dense column of ascending branches in scale foliage, 3 LODs."
    public static let tags = ["nature", "tree", "conifer"]
    public static let budget = 45_000
    public static let author = "realityhd"

    /// Total height in meters.
    public var height: Float = 18
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var sp = TreeSpecies.cypress
        sp.height = height
        return ConiferBuild.lods(sp, seed: seed) { m, _ in
            ConiferBuild.envelopeShade(&m, leaf: sp.leaf, blend: 0.75, up: 0.15)
        }
    }
}
