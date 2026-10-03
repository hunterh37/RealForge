import simd
import Foundation

/// Talus fan about 4 x 3 m and 1.2 m high: angular broken rocks at the angle of repose (about 34 degrees)
/// over a gravel core, larger blocks rolled to the toe. One mesh, 3 LODs.
public struct ScreePile: RealAsset {
    public static let id = "scree-pile"
    public static let summary = "Talus fan, 4 x 3 m, 1.2 m high: angular broken rocks on a gravel core, large blocks at the toe, 3 LODs."
    public static let tags = ["nature", "rock"]
    public static let budget = 50_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 20, elevation: 22)

    /// Footprint (x, z) and height in meters.
    public var footprint: V2 = V2(4, 3)
    public var height: Float = 1.2
    public var rocks = 240
    public var material: MaterialKey = "rock.basalt"
    public var lodDistances: [Float] = [15, 40]
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        let ns = UInt32(truncatingIfNeeded: seed) &+ 5
        let hx = footprint.x / 2, hz = footprint.y / 2
        // Fan: apex toward -z (against an imagined cliff), spreading to +z.
        func heap(_ p: V2) -> Float {
            let q = V2(p.x / hx, (p.y + hz * 0.6) / (hz * 1.6))
            let r = simd_length(V2(q.x, max(q.y, 0) * 1.0 + min(q.y, 0) * 2.5))
            let n = Noise.fbm(V3(p.x, 0, p.y) * 0.9, octaves: 3, seed: ns) * 0.25
            return height * powf(max(0, 1 - r + n * 0.3), 1.15) - 0.06
        }
        var parts: [RockPart] = []
        let angular = RockShape().with {
            $0.lumps = 0.03; $0.erosion = 0.02; $0.detail = 0.008; $0.squareness = 3
            $0.facets = 10; $0.chips = 3; $0.facetDepth = 0.35...0.62; $0.sink = 0.3
        }
        var tries = 0
        var placed: [(V2, Float)] = []
        while parts.count < rocks && tries < rocks * 30 {
            tries += 1
            let p = V2(rng.float(-hx...hx), rng.float(-hz...hz))
            let h = heap(p)
            guard h > -0.02 else { continue }
            // Sorting: blocks get larger toward the toe (low on the fan).
            let toe = 1 - saturate(h / height)
            let s = rng.float(0.07...0.2) * (1 + toe * 1.6) * (rng.chance(0.06) ? 1.8 : 1)
            if placed.contains(where: { simd_distance($0.0, p) < ($0.1 + s) * 0.3 }) { continue }
            placed.append((p, s))
            // Settle onto the slope: tilt toward the local gradient.
            let gx = heap(p + V2(0.05, 0)) - heap(p - V2(0.05, 0)), gz = heap(p + V2(0, 0.05)) - heap(p - V2(0, 0.05))
            let up = simd_normalize(V3(-gx / 0.1, 1, -gz / 0.1))
            let tilt = simd_quatf(from: V3(0, 1, 0), to: up)
            parts.append(RockPart(shape: angular.with { $0.size = V3(s * rng.float(1.1...1.6), s * rng.float(0.45...0.8), s); $0.bevel = s * 0.04 },
                                  seed: seed &+ UInt64(parts.count + 1),
                                  xform: Xform(translation: V3(p.x, max(h, 0) - s * 0.15, p.y), rotation: tilt), material: material))
        }
        let sizes = placed.map { $0.1 }
        let core = { (seg: Int) -> Surface in
            // Gravel core: small worley bumps read as fines between the blocks.
            var c = Prim.terrain(size: footprint * 1.02, segments: seg, material: material) { p in
                let w = Noise.worley(V3(p.x, 0, p.y) * 9, seed: ns &+ 3)
                return heap(p) - 0.07 + 0.06 * (1 - min(1, w.f1 * 1.2)) * smoothstep(-0.05, 0.1, heap(p))
            }
            c.occlusion = c.positions.map { 0.6 + 0.25 * smoothstep(0, 0.6, $0.y) }
            return c
        }
        var levels = rockCluster(name: Self.id, parts: parts, lods: 3, facets: true) { i, lod in
            let s = sizes[i]
            switch lod {
            case 0: return s > 0.25 ? 4 : 3
            case 1: return s > 0.15 ? 2 : nil
            default: return s > 0.3 ? 2 : nil
            }
        }
        for (k, seg) in [72, 30, 14].enumerated() { levels[k].add(core(seg)) }
        return LODModel(levels: levels, switchDistances: lodDistances)
    }
}
