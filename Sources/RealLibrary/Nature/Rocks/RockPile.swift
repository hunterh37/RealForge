import simd
import Foundation

/// Heap of cleared field stones about 1.8 m across and 0.7 m high: 40 to 60 rounded stones of 15 to 40 cm
/// stacked in layers on a soil core. One mesh, 3 LODs.
public struct RockPile: RealAsset {
    public static let id = "rock-pile"
    public static let summary = "Field stone heap, 1.8 m across, 0.7 m high: 40-60 rounded stones stacked in layers, 3 LODs."
    public static let tags = ["nature", "rock", "farm"]
    public static let budget = 30_000
    public static let author = "realityhd"

    public var radius: Float = 0.9
    public var height: Float = 0.7
    public var stones: ClosedRange<Int> = 40...60
    public var material: MaterialKey = "rock.granite"
    public var lodDistances: [Float] = [12, 30]
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        func dome(_ d: Float) -> Float { height * max(0, 1 - (d / radius) * (d / radius)) }
        let field = RockShape().with {
            $0.lumps = 0.14; $0.erosion = 0.03; $0.warp = 0.5; $0.facets = 4; $0.chips = 1
            $0.facetDepth = 0.75...0.9; $0.squareness = 2.2; $0.sink = 0.25; $0.flatBase = 0.4
        }
        let count = rng.int(stones)
        var parts: [RockPart] = []
        var placed: [(V3, V3)] = []   // center, half extents
        // Height of the pile surface at p: soil core or the top of a stone already placed.
        func surface(_ p: V2) -> Float {
            var h = dome(simd_length(p)) * 0.4 - 0.05
            for (c, e) in placed {
                let q = V2((p.x - c.x) / e.x, (p.y - c.z) / e.z), d2 = simd_length_squared(q)
                if d2 < 1 { h = max(h, c.y + e.y * (1 - d2).squareRoot()) }
            }
            return h
        }
        var tries = 0
        while parts.count < count && tries < count * 60 {
            tries += 1
            let p = rng.inDisc(radius: radius * 0.92), d = simd_length(p)
            let s = rng.float(0.15...0.36) * (1 + 0.35 * d / radius)
            // Mesh spans [-0.1 h, 0.9 h] about its origin (h = 0.8 s); rest it on the surface, embedded 20 percent.
            let h = s * 0.8, e = V3(s * 0.62, h / 2, s * 0.5)
            let base = surface(p) - h * 0.2
            guard base + h < dome(d) + 0.12 else { continue }
            let origin = V3(p.x, max(0, base + h * 0.1), p.y)
            let c = origin + V3(0, h * 0.4, 0)
            if placed.contains(where: { simd_distance($0.0, c) < ($0.1.x + e.x) * 0.62 }) { continue }
            placed.append((c, e))
            let rot = simd_quatf(degrees: rng.float(0...360), axis: V3(0, 1, 0)) *
                      simd_quatf(degrees: rng.float(-20...20), axis: V3(1, 0, 0))
            parts.append(RockPart(shape: field.with { $0.size = V3(s * 1.25, s * 0.8, s); $0.bevel = s * 0.08; $0.sink = 0.1 },
                                  seed: seed &+ UInt64(parts.count + 1), xform: Xform(translation: origin, rotation: rot), material: material))
        }
        let sizes = placed.map { $0.1.x / 0.62 }
        var levels = rockCluster(name: Self.id, parts: parts, lods: 3) { i, lod in
            [sizes[i] > 0.3 ? 7 : 6, 3, sizes[i] > 0.25 ? 2 : nil][lod]
        }
        for (k, seg) in [32, 16, 8].enumerated() {
            var core = Prim.terrain(size: V2(radius, radius) * 2, segments: seg, material: material) { p in
                dome(simd_length(p)) * 0.4 - 0.08
            }
            core.occlusion = core.positions.map { _ in 0.45 }
            levels[k].add(core)
        }
        return LODModel(levels: levels, switchDistances: lodDistances)
    }
}
