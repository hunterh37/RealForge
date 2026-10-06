import simd
import Foundation

/// Small bunch of cilantro lying on the counter, 18 cm: five thin stems gathered at -X fanning out,
/// each forking near its end into three short stalks carrying flat fan-shaped leaflets with three
/// rounded, toothed lobes. Leaves are thin closed blades (veins from `food.cilantro`), stems closed
/// tubes. Cook kind `leaf`: wilts dark.
public struct CilantroBunch: RealFood {
    public static let id = "cilantro-bunch"
    public static let summary = "Cilantro bunch, 18 cm: thin green stems with fan-lobed flat leaves; wilts."
    public static let tags = ["prop", "food", "kitchen", "handheld"]
    public static let budget = 7000
    public static let author = "realityhd"
    public static let kind = FoodKind.leaf
    public static let preview = PreviewHint(azimuth: 20, elevation: 55, distance: 0.36, studio: true)

    /// Stem count.
    public var stems = 5
    /// Stem length (m).
    public var stemLength: Float = 0.12
    /// Material keys.
    public var leaf: MaterialKey = "food.cilantro"
    public var stem: MaterialKey = "food.herb-stem"
    public var stemCut: MaterialKey = "food.herb-stem-section"
    public init() {}

    public var coreCenter: V3 { V3(0, 0.002, 0) }

    public func capMaterial(for key: MaterialKey) -> MaterialKey? {
        if key == stem { return stemCut }
        if key == leaf { return leaf }
        return nil
    }

    static func leaflet(length: Float, width: Float, base: V3, dir: V3, lift: Float, material: MaterialKey, rng: inout SeededRNG) -> Surface {
        let ph = rng.float(0...6.28)
        var b = RecipeMesh.blade(length: length, thickness: 0.00018, edge: 0.0023, uCenter: 0.015, material: material) { t in
            // Wedge base, three rounded lobes with small teeth near the top.
            let wedge = pow(smoothstep(0, 0.6, t), 0.8)
            let lobes = 0.86 + 0.14 * cos(t * 2 * .pi * 2.2 + 0.6)
            let teeth = 1 - 0.035 * max(0, sin(t * 26 + ph)) * smoothstep(0.35, 0.8, t)
            let round = sqrt(max(0, 1 - pow(max(0, t - 0.62) / 0.38, 2)))
            return max(0.0003, width * wedge * lobes * teeth * round)
        }
        let up = V3(0, 1, 0)
        let d = simd_normalize(V3(dir.x, 0, dir.z))
        let side = simd_normalize(simd_cross(up, d))
        let curl = rng.float(-0.06...0.06)
        b.deform { q in
            let t = q.y / length
            let h = lift * (1 - t) + 0.0012 * sin(.pi * t) + curl * q.x - 0.03 * q.x * q.x / max(width, 1e-4)
            return base + d * q.y + side * q.x + up * (q.z + h)
        }
        return RecipeMesh.outward(b)
    }

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var stemsS = Surface(material: stem)
        var leaves = Surface(material: leaf)
        for i in 0..<stems {
            var r = rng.fork(i)
            let ang = (Float(i) / Float(max(1, stems - 1)) - 0.5) * 0.5 + r.float(-0.05...0.05)
            let len = stemLength * r.float(0.8...1.05)
            let dir = V3(cos(ang), 0, sin(ang))
            let start = V3(0, 0.0011, Float(i - stems / 2) * 0.0015)
            let end = start + dir * len + V3(0, 0.0015, 0)
            let mid = (start + end) / 2 + V3(0, 0.0012, r.float(-0.004...0.004))
            let path = catmull([start, mid, end], per: 4)
            stemsS.append(FoodMesh.tube(path, radii: path.indices.map { 0.0011 - 0.0004 * Float($0) / Float(path.count - 1) }, sides: 6,
                                        endBulge: 0.2, material: stem))
            // Fork: three short stalks with a leaflet each.
            for k in 0..<3 {
                var rk = r.fork(10 + k)
                let a2 = ang + (Float(k) - 1) * 0.55 + rk.float(-0.15...0.15)
                let d2 = V3(cos(a2), 0, sin(a2))
                let sl = rk.float(0.008...0.016)
                let p2 = end + d2 * sl + V3(0, 0.0004, 0)
                stemsS.append(FoodMesh.tube([end - dir * 0.002, (end + p2) / 2 + V3(0, 0.0005, 0), p2], radii: [0.0006, 0.0005, 0.0004],
                                            sides: 5, endBulge: 0.3, material: stem))
                let ll = rk.float(0.016...0.022)
                leaves.append(Self.leaflet(length: ll, width: ll * rk.float(0.5...0.6), base: p2 - d2 * 0.001, dir: d2, lift: 0.0012,
                                           material: leaf, rng: &rk))
            }
            // A side leaflet pair partway up the stem.
            if r.float() < 0.7 {
                let t = r.float(0.55...0.75)
                let p = start + (end - start) * t + V3(0, 0.0012, 0)
                for sgn in [Float(-1), 1] {
                    var rk = r.fork(Int(sgn) + 30)
                    let d2 = V3(cos(ang + sgn * 0.9), 0, sin(ang + sgn * 0.9))
                    let ll = rk.float(0.012...0.016)
                    leaves.append(Self.leaflet(length: ll, width: ll * 0.55, base: p, dir: d2, lift: 0.001, material: leaf, rng: &rk))
                }
            }
        }
        var m = Model(name: Self.id)
        m.add(stemsS)
        m.add(leaves)
        let b = m.bounds
        m = m.transformed(Xform(translation: V3(-(b.min.x + b.max.x) / 2, -b.min.y, -(b.min.z + b.max.z) / 2)))
        groundAO(&m, height: 0.005, floor: 0.7)
        return LODModel(m)
    }
}
