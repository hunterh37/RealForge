import simd
import Foundation

/// Filled sandbag, about 0.55 x 0.3 x 0.12 m lying flat (a 0.36 x 0.66 m bag two thirds full): slumped pillow
/// with a side seam and a folded, tied neck. `courses` > 1 stacks bags in running bond.
public struct Sandbag: RealAsset {
    public static let id = "sandbag"
    public static let summary = "Filled jute sandbag: slumped pillow with side seam and tied neck; stacks in running bond with courses > 1."
    public static let tags = ["prop", "construction", "fabric", "barrier"]
    public static let budget = 12_000
    public static let author = "hunter"
    public static let preview = PreviewHint(azimuth: 30, elevation: 22)

    /// Rows in the stack (1 = a single bag). Each course has one bag fewer than the one below.
    public var courses = 1
    /// Bags in the bottom course.
    public var perCourse = 4
    public var material: MaterialKey = "sack.jute"
    public init() {}

    static func bag(_ rng: inout SeededRNG, seed: UInt32, sub: Int, material: MaterialKey) -> Surface {
        let hx = rng.vary(0.27, 0.05), hy = rng.vary(0.065, 0.1), hz = rng.vary(0.15, 0.05)
        var s = CFKit.blob(half: V3(hx, hy, hz), power: 3, subdivisions: sub, material: material) { p in
            let seam = 0.004 * exp(-pow(p.y / 0.006, 2))
            // Lumps from the fill plus wrinkles running across the bag.
            let wrinkle = sin(p.x * 38 + Noise.perlin(p * 6, seed: seed &+ 3) * 4) * 0.004 * smoothstep(0.0, 0.03, p.y)
            return Noise.fbm(p * 7, octaves: 3, seed: seed) * 0.016 + seam + wrinkle
        }
        s.positions = s.positions.map { p0 in
            var p = p0
            // Neck: the last 8 cm taper and fold flat.
            let k = smoothstep(hx - 0.1, hx, p.x)
            p.z *= 1 - 0.35 * k
            p.y = p.y * (1 - 0.55 * k) - 0.02 * k
            // Slump: belly settles, base flattens, top dips in the middle.
            if p.y < 0 { p.y *= 0.55; p.z *= 1.06 } else { p.y *= 1 - 0.18 * (1 - abs(p.x) / hx) }
            return p
        }
        s.recomputeNormals()
        s.computeTangents()
        s.bakeCavityAO(strength: 0.6, floor: 0.6)
        let minY = s.bounds.min.y
        return s.transformed(Xform(translation: V3(0, -minY, 0)))
    }

    public func build(seed: UInt64) -> LODModel {
        func level(_ sub: Int) -> Model {
            var rng = SeededRNG(seed: seed)
            var m = Model(name: Self.id)
            let ns = UInt32(truncatingIfNeeded: seed)
            if courses <= 1 {
                m.add(Self.bag(&rng, seed: ns, sub: sub, material: material), Xform(rotation: simd_quatf(degrees: rng.float(-8...8), axis: .up)))
            } else {
                let pitch: Float = 0.5, rise: Float = 0.1
                for c in 0..<courses {
                    let n = max(1, perCourse - c)
                    for i in 0..<n {
                        let x = (Float(i) - Float(n - 1) / 2) * pitch
                        let b = Self.bag(&rng, seed: ns &+ UInt32(c * 31 + i), sub: sub, material: material)
                        m.add(b, Xform(translation: V3(x + rng.float(-0.02...0.02), Float(c) * rise - (c > 0 ? 0.02 : 0), rng.float(-0.02...0.02)),
                                       rotation: simd_quatf(degrees: rng.float(-4...4), axis: .up)))
                    }
                }
            }
            groundAO(&m, height: 0.1, floor: 0.55)
            return m
        }
        return LODModel(levels: [level(10), level(5)], switchDistances: [12])
    }
}
