import simd
import Foundation

/// Russet baking potato lying along +X: an oblong, slightly flattened tuber with low lumps, a few
/// shallow eyes (dimples with a raised brow) spiralling toward the bud end, and a stem scar at the
/// other end. One closed body in netted corky skin; cut face `food.potato-flesh` (creamy flesh with
/// vascular ring, tile = tuber depth, centered on the long axis).
public struct RussetPotato: RealFood {
    public static let id = "russet-potato"
    public static let summary = "Russet potato, 13 cm: oblong lumpy tuber with netted corky skin and shallow eyes; creamy flesh with vascular ring."
    public static let tags = ["prop", "food", "kitchen", "handheld"]
    public static let budget = 6000
    public static let author = "realityhd"
    public static let kind = FoodKind.root
    public static let preview = PreviewHint(azimuth: 30, elevation: 28, distance: 0.34, studio: true)

    /// Bounding size: length X, height Y, width Z (m).
    public var size = V3(0.13, 0.055, 0.07)
    /// Eye count.
    public var eyes = 9
    /// Material keys.
    public var skin: MaterialKey = "food.potato"
    public var flesh: MaterialKey = "food.potato-flesh"
    public init() {}

    public var coreCenter: V3 { V3(0, size.y / 2, 0) }

    public func capMaterial(for key: MaterialKey) -> MaterialKey? { key == skin ? flesh : nil }

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        let L = size.x, R = size.z / 2
        var s = FoodMesh.revolve(edge: 0.0042, seamTile: 0.06, material: skin) { t in
            let a = Float.pi * t
            return V2(R * pow(sin(a), 0.8) * (1 + 0.06 * cos(a)), L * (0.5 - 0.5 * cos(a)))
        }
        // Lumps: a few broad bumps and dents.
        let lumps = (0..<7).map { _ in (rng.unitVector(), rng.float(-0.004...0.005), rng.float(0.5...1.0)) }
        // Eyes: spiral toward the bud end (high y), each a dimple with a brow on the stem side.
        let eyesAt = (0..<eyes).map { i -> (Float, Float) in
            let t = 0.15 + 0.8 * Float(i) / Float(max(1, eyes - 1)) + rng.float(-0.04...0.04)
            return (t * L, Float(i) * 2.4 + rng.float(-0.3...0.3))
        }
        s.deform { p in
            let r = simd_length(V2(p.x, p.z)), a = atan2(p.z, p.x)
            let dir = simd_normalize(V3(p.x / R, (p.y - L / 2) / (L / 2), p.z / R) + V3(0, 1e-5, 0))
            var k: Float = 0
            for (d, amp, w) in lumps { k += amp * smoothstep(1 - 0.5 * w, 1, simd_dot(dir, d)) }
            for (ey, ea) in eyesAt {
                let da = atan2(sin(a - ea), cos(a - ea)) * max(r, 0.005)
                let dy = p.y - ey
                let d2 = (da * da + dy * dy) / (0.0035 * 0.0035)
                k -= 0.0034 * exp(-d2)
                let by = dy + 0.0042
                k += 0.0013 * exp(-(da * da / (0.005 * 0.005) + by * by / (0.0016 * 0.0016)))
            }
            let rr = max(0, r + k * smoothstep(0, 0.006, r))
            let f = r > 1e-6 ? rr / r : 1
            return V3(p.x * f, p.y, p.z * f)
        }
        var m = Model(name: Self.id)
        m.add(FoodMesh.fit(FoodMesh.layAlongX(s), size: size))
        groundAO(&m, height: 0.012, floor: 0.55)
        return LODModel(m)
    }
}
