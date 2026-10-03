import simd
import Foundation

/// Red sandstone butte about 8 x 6 x 7 m: flat caprock, stepped strata ledges with undercut soft beds,
/// fallen blocks at the foot. 3 LODs.
public struct MesaRock: RealAsset {
    public static let id = "mesa-rock"
    public static let summary = "Red sandstone butte, 6 m tall: flat caprock, stepped strata ledges, undercut soft beds, fallen blocks, 3 LODs."
    public static let tags = ["nature", "rock", "desert"]
    public static let budget = 46_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 25, elevation: 12)

    public var size: V3 = V3(8, 6, 7)
    public var material: MaterialKey = "rock.redstone"
    /// Mean bed thickness and ledge depth in meters.
    public var bedHeight: Float = 0.7
    public var ledgeDepth: Float = 0.35
    public var blocks: ClosedRange<Int> = 4...7
    public var lodDistances: [Float] = [40, 100]
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        let main = RockShape().with {
            $0.size = size; $0.lumps = 0.16; $0.erosion = 0.1; $0.warp = 0.6; $0.facets = 9; $0.chips = 8
            $0.facetDepth = 0.7...0.95; $0.bevel = 0.1; $0.squareness = 2.7; $0.flatTop = 1; $0.gullies = 0.12
            $0.strata = ledgeDepth; $0.bedHeight = bedHeight; $0.sink = 0.06; $0.flatBase = 0.8
        }
        var parts = [RockPart(shape: main, seed: seed, xform: .identity, material: material)]
        let nb = rng.int(blocks)
        for k in 0..<nb {
            let a = rng.float(0...(2 * .pi)), s = rng.float(0.7...1.8)
            let pos = V3(cos(a) * size.x * 0.52, 0, sin(a) * size.z * 0.52)
            parts.append(RockPart(shape: main.with {
                $0.size = V3(s * 1.4, s * 0.8, s); $0.strata = 0.05; $0.bedHeight = 0.25; $0.flatTop = 0
                $0.squareness = 2.8; $0.bevel = 0.03; $0.gullies = 0; $0.facets = 6; $0.chips = 4; $0.sink = 0.2; $0.flatBase = 0.5
            }, seed: seed &+ UInt64(20 + k), xform: Xform(translation: pos, rotation: simd_quatf(degrees: rng.float(-15...15), axis: V3(1, 0, 0))),
               material: material))
        }
        let levels = rockCluster(name: Self.id, parts: parts, lods: 3) { i, lod in
            if i == 0 { return [54, 24, 11][lod] }
            return lod == 2 ? nil : [10, 5, 0][lod]
        }
        return LODModel(levels: levels, switchDistances: lodDistances)
    }
}
