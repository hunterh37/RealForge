import simd
import Foundation

/// Scatter of 8 to 20 small rounded stones, 4 to 14 cm, over a 1.2 m disc, in one mesh.
public struct Pebbles: RealAsset {
    public static let id = "pebbles"
    public static let summary = "Cluster of 8-20 small rounded stones, 4-14 cm, in one mesh."
    public static let tags = ["nature", "rock"]
    public static let budget = 10_000
    public var radius: Float = 0.6
    public var count = 14
    public var material: MaterialKey = "rock.river"
    public init() {}
    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        let pebble = RockShape().with {
            $0.lumps = 0.1; $0.erosion = 0; $0.detail = 0.006; $0.facets = 2; $0.chips = 0
            $0.facetDepth = 0.75...0.9; $0.squareness = 2.2; $0.sink = 0.25; $0.flatBase = 0.35
        }
        let parts = (0..<count).map { i -> RockPart in
            let p = rng.inDisc(radius: radius), sz = rng.float(0.04...0.14)
            return RockPart(shape: pebble.with { $0.size = V3(sz * 1.3, sz * 0.6, sz); $0.bevel = sz * 0.1 },
                            seed: seed &+ UInt64(i), xform: Xform(translation: V3(p.x, 0, p.y)), material: rng.chance(0.3) ? "rock.granite" : material)
        }
        return LODModel(rockCluster(name: Self.id, parts: parts, lods: 1) { _, _ in 6 }[0])
    }
}
