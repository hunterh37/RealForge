import simd
import Foundation

/// Granite boulder: cube-sphere with ridged displacement, planar fracture facets, flattened, sunk base.
public struct Boulder: RealAsset {
    public static let id = "boulder"
    public static let summary = "Faceted granite boulder, cube-sphere + ridged noise + fracture planes, 3 LODs."
    public static let tags = ["nature", "rock"]
    public static let budget = 12_000

    public var size: V3 = V3(1.6, 1.0, 1.3)
    public var material: MaterialKey = "rock.granite"
    public var facets = 9
    public var roughness: Float = 0.3
    /// Cube-sphere subdivisions per LOD.
    public var detail: [Int] = [28, 12, 5]
    public var lodDistances: [Float] = [10, 30]
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        let s = V3(rng.vary(size.x, 0.2), rng.vary(size.y, 0.25), rng.vary(size.z, 0.2)) / 2
        let ns = UInt32(truncatingIfNeeded: seed)
        var planes: [(V3, Float)] = []
        for _ in 0..<facets {
            var n = rng.unitVector(); n.y = abs(n.y) * 0.8 + 0.1
            planes.append((simd_normalize(n), rng.float(0.62...0.85)))
        }
        let r = roughness
        func shape(_ d: V3) -> V3 {
            var p = d
            let big = Noise.fbm(d * 1.3, octaves: 3, seed: ns) * 0.35
            let ridge = Noise.ridged(d * 2.4, octaves: 4, seed: ns &+ 7) * 0.5
            p *= 1 + (big + ridge - 0.2) * r * 2.2
            // Fracture facets: clamp to random planes (scaled space) for broken-stone flats.
            for (n, k) in planes { let dd = simd_dot(p, n); if dd > k { p -= n * (dd - k) * 0.92 } }
            var q = p * s
            if q.y < -s.y * 0.55 { q.y = -s.y * 0.55 + (q.y + s.y * 0.55) * 0.15 }  // flat-ish base
            return q
        }
        func lod(_ n: Int) -> Model {
            var surf = Prim.cubeSphere(subdivisions: n, material: material, radius: shape)
            let minY = surf.bounds.min.y
            surf.positions = surf.positions.map { V3($0.x, $0.y - minY - s.y * 0.18, $0.z) }  // sink into ground
            surf.occlusion = surf.positions.map { 0.35 + 0.65 * smoothstep(-0.05, s.y * 0.5, $0.y) }  // contact shadow
            surf.bakeCavityAO(strength: 1.2)
            return Model(name: Self.id, surfaces: [surf])
        }
        return LODModel(levels: detail.map(lod), switchDistances: Array(lodDistances.prefix(detail.count - 1)))
    }
}
