import simd
import Foundation

/// Group of 5 to 9 water-worn river stones, 12 to 40 cm long and flattened, over about 1.2 m. Set `wet` for
/// the darker, glossy look of stones at the waterline. 2 LODs.
public struct RiverStones: RealAsset {
    public static let id = "river-stones"
    public static let summary = "Group of 5-9 smooth flattened river stones, 12-40 cm, over 1.2 m; wet knob darkens and glosses them, 2 LODs."
    public static let tags = ["nature", "rock", "water"]
    public static let budget = 12_000
    public static let author = "realforge"
    public static let preview = PreviewHint(azimuth: 30, elevation: 35)

    public var radius: Float = 0.6
    public var count: ClosedRange<Int> = 5...9
    /// Wet stones use `rock.river-wet`.
    public var wet = false
    public var lodDistances: [Float] = [10]
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        let material: MaterialKey = wet ? "rock.river-wet" : "rock.river"
        let smooth = RockShape().with {
            $0.lumps = 0.07; $0.erosion = 0; $0.detail = 0.004; $0.warp = 0.3; $0.facets = 0; $0.chips = 0
            $0.squareness = 2.3; $0.sink = 0.3; $0.flatBase = 0.3
        }
        let n = rng.int(count)
        var parts: [RockPart] = []
        var placed: [(V2, Float)] = []
        var tries = 0
        while parts.count < n && tries < n * 40 {
            tries += 1
            let p = rng.inDisc(radius: radius), s = rng.float(0.12...0.4)
            if placed.contains(where: { simd_distance($0.0, p) < ($0.1 + s) * 0.5 }) { continue }
            placed.append((p, s))
            parts.append(RockPart(shape: smooth.with { $0.size = V3(s, s * rng.float(0.28...0.42), s * rng.float(0.6...0.8)) },
                                  seed: seed &+ UInt64(parts.count + 1),
                                  xform: Xform(translation: V3(p.x, 0, p.y), rotation: simd_quatf(degrees: rng.float(-6...6), axis: V3(1, 0, 0))),
                                  material: material))
        }
        let sizes = placed.map { $0.1 }
        let levels = rockCluster(name: Self.id, parts: parts, lods: 2) { i, lod in
            lod == 0 ? (sizes[i] > 0.25 ? 10 : 8) : 4
        }
        return LODModel(levels: levels, switchDistances: lodDistances)
    }
}
