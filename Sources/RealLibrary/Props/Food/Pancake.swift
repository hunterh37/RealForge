import simd
import Foundation

/// Poured pancake batter: a closed disk with a flat bottom, a rounded rim that spreads slightly
/// unevenly, a gently domed top and a few bubble pits. Raw `food.batter` (bubbles and flour specks)
/// cooks to `food.batter-cooked`; cut face `food.batter`.
public struct Pancake: RealFood {
    public static let id = "pancake"
    public static let summary = "Poured pancake, 11 cm: irregular round batter disk with domed bubbly top and rounded rim; cooks to golden crumb."
    public static let tags = ["prop", "food", "kitchen", "handheld"]
    public static let budget = 5000
    public static let author = "realityhd"
    public static let kind = FoodKind.batter
    public static let preview = PreviewHint(azimuth: 25, elevation: 40, distance: 0.3, studio: true)

    /// Diameter (m).
    public var diameter: Float = 0.11
    /// Center thickness (m).
    public var thickness: Float = 0.011
    /// Bubble pits on top.
    public var bubbles = 34
    /// Material key.
    public var batter: MaterialKey = "food.batter"
    public init() {}

    public var coreCenter: V3 { V3(0, thickness / 2, 0) }

    public func capMaterial(for key: MaterialKey) -> MaterialKey? { key == batter ? batter : nil }

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        let R = diameter / 2 / 1.01, T = thickness, rim = T * 0.42
        // Profile: bottom center, flat bottom, rounded rim (radius ~ rim), domed top to the center.
        var pts: [V2] = [V2(0, 0), V2(R * 0.5, 0), V2(R - rim, 0)]
        for k in 1...6 { let a = -Float.pi / 2 + Float(k) / 6 * Float.pi * 0.85; pts.append(V2(R - rim + cos(a) * rim, rim + sin(a) * rim)) }
        pts += [V2(R * 0.82, T * 0.86), V2(R * 0.5, T * 0.97), V2(0, T)]
        var s = FoodMesh.revolve(edge: 0.003, seamTile: 0.05, material: batter, curve: FoodMesh.profile(pts, per: 4))
        let ph = (0..<4).map { _ in rng.float(0...6.28) }
        let pits = (0..<bubbles).map { _ -> (V2, Float) in
            let d = rng.inDisc(radius: R * 0.82)
            return (d, rng.float(0.0018...0.0035))
        }
        s.deform { p in
            let a = atan2(p.z, p.x), r = simd_length(V2(p.x, p.z))
            let k = 1 + 0.018 * sin(a * 2 + ph[0]) + 0.012 * sin(a * 5 + ph[1]) + 0.008 * sin(a * 11 + ph[2])
            var q = V3(p.x * k, p.y, p.z * k)
            if p.y > rim * 1.2 {
                // Bubble pits: small craters with a raised lip on the top face.
                for (c, pr) in pits {
                    let d = simd_distance(V2(q.x, q.z), c) / pr
                    q.y += -0.0012 * exp(-d * d * 2) + 0.0003 * exp(-pow(d - 1.3, 2) * 4)
                }
                q.y += 0.0004 * sin(r * 260 + ph[3]) * (r / R)
            }
            return q
        }
        var m = Model(name: Self.id)
        m.add(FoodMesh.planarUV(s))
        groundAO(&m, height: 0.006, floor: 0.7)
        return LODModel(m)
    }
}
