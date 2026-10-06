import simd
import Foundation

/// Ripe Cavendish banana lying on its side, 19 cm along the curve. One closed body: the peel is a
/// 2.5 mm thick-walled shell with a softened five-sided section (ridges along the length, freckles
/// in `food.banana-peel`), the cream flesh is a solid inside it (cut face `food.banana-flesh`), a
/// green-brown stem continues from one end and a dark blossom nub caps the other. The peel and the
/// flesh are separate shells, so the app can hide the peel to show a peeled banana.
public struct Banana: RealFood {
    public static let id = "banana"
    public static let summary = "Ripe Cavendish banana, 19 cm: curved ridged yellow peel with freckles, green-brown stem, dark tip, cream flesh inside."
    public static let tags = ["prop", "food", "kitchen", "handheld"]
    public static let budget = 7000
    public static let author = "realityhd"
    public static let kind = FoodKind.vegetable
    public static let preview = PreviewHint(azimuth: 20, elevation: 40, distance: 0.42, studio: true)

    /// Length along the curve, stem base to tip (m).
    public var length: Float = 0.165
    /// Max peel radius (m).
    public var radius: Float = 0.0185
    /// Curve radius of the arc (m).
    public var bend: Float = 0.15
    /// Peel thickness (m).
    public var peelThickness: Float = 0.0025
    /// Material keys.
    public var peel: MaterialKey = "food.banana-peel"
    public var peelCut: MaterialKey = "food.banana-peel-section"
    public var flesh: MaterialKey = "food.banana-flesh"
    public var tip: MaterialKey = "food.banana-tip"
    public var stem: MaterialKey = "food.stem-green:7E7A3E"
    public init() {}

    public var coreCenter: V3 { V3(0, radius, 0) }

    public func capMaterial(for key: MaterialKey) -> MaterialKey? {
        switch key {
        case peel: return peelCut
        case flesh: return flesh
        default: return nil
        }
    }

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        let L = length, R = radius, Rb = bend
        let arcA = L / Rb
        let n = 40
        // Arc in the XZ plane, concave toward +Z, lying at the body's mid height.
        let path: [V3] = (0...n).map { i in
            let a = -arcA / 2 + arcA * Float(i) / Float(n)
            return V3(Rb * sin(a), R * 0.92, Rb * (1 - cos(a)))
        }
        let ph = rng.float(0...6.28)
        let peelR: (Float) -> Float = { t in
            let body = pow(sin(.pi * min(1, max(0, t))), 0.55)
            let neck = 0.32 + 0.68 * smoothstep(0, 0.22, t)      // stem end narrows into the neck
            let blossom = 0.5 + 0.5 * (1 - smoothstep(0.82, 1, t))
            return R * max(0.12, body * neck * (0.6 + 0.4 * blossom))
        }
        let outer = RecipeMesh.sweep(path, edge: 0.0046, endBulge: 0.3, seamTile: 0.12, material: peel) { t, a in
            let r = peelR(t)
            return r * (1 + 0.055 * cos(5 * a + ph)) * (1 - 0.06 * sin(a) * sin(a))
        }
        var peelS = outer
        peelS.append(FoodMesh.offset(outer, by: -peelThickness).flipped())
        // Flesh: a rounder solid inside the peel, short of both ends.
        let fleshPath = Array(path[6...36])
        let fleshS = RecipeMesh.sweep(fleshPath, edge: 0.006, endBulge: 0.7, seamTile: 0.05, material: flesh) { t, a in
            let tt = 0.15 + t * 0.75
            return max(0.002, (peelR(tt) - peelThickness - 0.0005) * (1 + 0.03 * cos(3 * a)) * pow(sin(.pi * min(1, t * 1.02)), 0.25))
        }
        // Stem continuing from the start of the arc, slightly upturned, flat cut end.
        let t0 = simd_normalize(path[0] - path[1])
        let s0 = path[0] + t0 * 0.002
        let stemPts = [s0 - t0 * 0.006, s0 + t0 * 0.008 + V3(0, 0.002, 0), s0 + t0 * 0.02 + V3(0, 0.005, 0)]
        let stemS = FoodMesh.tube(stemPts, radii: [0.0042, 0.0036, 0.0038], sides: 10, endBulge: 0.05, material: stem)
        // Blossom nub at the far end.
        let t1 = simd_normalize(path[n] - path[n - 1])
        var nub = FoodMesh.revolve(edge: 0.0012, seamTile: 0.02, material: tip) { t in
            let a = Float.pi * t
            return V2(0.0028 * sin(a), -0.003 + 0.0055 * (0.5 - 0.5 * cos(a)))
        }
        let q = simd_quatf(from: V3(0, 1, 0), to: t1)
        let pe = path[n] + t1 * 0.001
        nub.deform { p in pe + q.act(p) }
        var m = Model(name: Self.id)
        m.add(peelS)
        m.add(fleshS)
        m.add(stemS)
        m.add(nub)
        let b = m.bounds
        m = m.transformed(Xform(translation: V3(-(b.min.x + b.max.x) / 2, -b.min.y, -(b.min.z + b.max.z) / 2)))
        groundAO(&m, height: 0.01, floor: 0.6)
        return LODModel(m)
    }
}
