import simd
import Foundation

/// Scots pine (Pinus sylvestris), ~17 m: clear bole with grey-brown plated bark that turns orange and
/// flaky above ~45 percent of the height, flat-topped crown of a few heavy limbs, needle tufts at shoot tips.
public struct ScotsPine: RealAsset {
    public static let id = "scots-pine"
    public static let summary = "Scots pine, ~17 m: plated lower bole, orange flaking upper bark, flat-topped crown of needle tufts, 3 LODs."
    public static let tags = ["nature", "tree", "conifer"]
    public static let budget = 45_000
    public static let author = "realforge"

    /// Total height in meters.
    public var height: Float = 17
    /// Height fraction where the bark turns orange.
    public var orangeFrom: Float = 0.45
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var sp = TreeSpecies.scotsPine
        sp.height = height
        let ns = UInt32(truncatingIfNeeded: seed)
        let cut = height * orangeFrom
        return ConiferBuild.lods(sp, seed: seed) { m, _ in
            // Ragged transition over ~3 m: orange patches break through the grey plates.
            ConiferBuild.splitSurface(&m, "bark.scots-pine", into: "bark.scots-pine-upper") { c in
                let band = smoothstep(cut - 2, cut + 1.5, c.y + Noise.fbm(V3(c.x * 2, c.y * 0.5, c.z * 2), octaves: 3, seed: ns) * 2)
                return 0.5 + Noise.perlin(V3(c.x * 9, c.y * 3, c.z * 9), seed: ns &+ 1) < band * 1.2 - 0.1
            }
        }
    }
}
