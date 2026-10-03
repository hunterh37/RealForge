import simd
import Foundation

/// Standing feed sack, 0.45 m wide x 0.7 m tall x 0.24 m deep (about 25 kg): slumped jute body bulging at the
/// base, flat sewn top folded over to one side, a stitch line across the fold.
public struct FeedSack: RealAsset {
    public static let id = "feed-sack"
    public static let summary = "Standing jute feed sack, 0.7 m: slumped body bulging at the base, sewn top folded over."
    public static let tags = ["prop", "farm", "fabric", "container"]
    public static let budget = 3_500
    public static let author = "hunter"
    public static let preview = PreviewHint(azimuth: 25, elevation: 12)

    public var height: Float = 0.7
    public var material: MaterialKey = "sack.jute"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        let ns = UInt32(truncatingIfNeeded: seed)
        let h = rng.vary(height, 0.05), hw: Float = 0.225, hd: Float = 0.13
        let fold = rng.float(50...80) * (rng.chance(0.5) ? 1 : -1)
        let lean = rng.float(-4...4)
        func level(_ sub: Int) -> Model {
            var s = CFKit.blob(half: V3(hw, h / 2, hd), power: 2.6, subdivisions: sub, material: material) { p in
                Noise.fbm(p * 6, octaves: 3, seed: ns) * 0.018 + sin(p.y * 30 + Noise.perlin(p * 5, seed: ns &+ 5) * 5) * 0.004
            }
            s.positions = s.positions.map { p0 in
                var p = p0
                let t = (p.y + h / 2) / h                       // 0 base, 1 top
                // Bulge low, pinch to a flat seam at the top.
                p.x *= 1 + 0.12 * (1 - t) * (1 - t) - 0.05 * t
                p.z *= (1 + 0.25 * (1 - t) * (1 - t)) * (1 - 0.88 * smoothstep(0.62, 1.0, t))
                if t < 0.12 { p.y = -h / 2 + (p.y + h / 2) * 0.6 }
                // Fold the top 22% over about the X axis.
                let f0: Float = 0.74
                if t > f0 {
                    let pivot = V3(0, -h / 2 + f0 * h, 0)
                    let k = smoothstep(f0, 1.0, t)
                    p = pivot + simd_quatf(degrees: fold * k, axis: V3(1, 0, 0)).act(p - pivot)
                }
                p = simd_quatf(degrees: lean, axis: V3(0, 0, 1)).act(p)
                return p
            }
            s.recomputeNormals()
            s.computeTangents()
            let minY = s.bounds.min.y
            var m = Model(name: Self.id, surfaces: [s.transformed(Xform(translation: V3(0, -minY, 0)))])
            groundAO(&m, height: 0.15, floor: 0.55)
            return m
        }
        return LODModel(levels: [level(14), level(7)], switchDistances: [12])
    }
}
