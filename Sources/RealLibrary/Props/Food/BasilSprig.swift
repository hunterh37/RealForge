import simd
import Foundation

/// Genovese basil sprig lying on the counter: a square-section stem along +X with two opposite leaf
/// pairs, rotated 90 degrees at each node as on the plant, and a tip cluster of young leaves. Leaves
/// are thin closed blades on short petioles, cupped (edges curling down), arched off the stem and
/// resting their tips on the surface; the midrib and side veins come from `food.basil` (u across
/// the blade, midrib at its center).
public struct BasilSprig: RealFood {
    public static let id = "basil-sprig"
    public static let summary = "Basil sprig, 11 cm: square stem with opposite pairs of cupped glossy veined leaves and a tip cluster; wilts."
    public static let tags = ["prop", "food", "kitchen", "handheld"]
    public static let budget = 6000
    public static let author = "realityhd"
    public static let kind = FoodKind.leaf
    public static let preview = PreviewHint(azimuth: 20, elevation: 55, distance: 0.26, studio: true)

    /// Stem length (m).
    public var stemLength: Float = 0.085
    /// Largest leaf length (m).
    public var leafLength: Float = 0.05
    /// Material keys.
    public var leaf: MaterialKey = "food.basil"
    public var stem: MaterialKey = "food.herb-stem"
    public var stemCut: MaterialKey = "food.herb-stem-section"
    public init() {}

    public var coreCenter: V3 { V3(0, 0.002, 0) }

    public func capMaterial(for key: MaterialKey) -> MaterialKey? {
        if key == stem { return stemCut }
        if key == leaf { return leaf }
        return nil
    }

    /// One cupped leaf: base at `base`, pointing along `dir` (XZ), lifted `lift` at the base.
    static func leafShell(length: Float, width: Float, base: V3, dir: V3, lift: Float, cup: Float, droop: Float,
                          material: MaterialKey, rng: inout SeededRNG) -> Surface {
        let wob = rng.float(0...6.28)
        var b = RecipeMesh.blade(length: length, thickness: 0.00022, edge: 0.0021, uCenter: 0.03, material: material) { t in
            width * pow(sin(.pi * min(1, pow(t, 0.75) * 0.98 + 0.02)), 0.85) * (1 + 0.03 * sin(t * 20 + wob))
        }
        let up = V3(0, 1, 0)
        let d = simd_normalize(V3(dir.x, 0, dir.z))
        let side = simd_normalize(simd_cross(up, d))
        let twist = rng.float(-0.15...0.15)
        b.deform { q in
            let t = q.y / length
            let x = q.x / max(width, 1e-4)
            // Height: lifted at the base, arching, then settling the tip down; edges curl down.
            let h = lift * (1 - t) + droop * sin(.pi * t) * (1 - t * 0.6) - cup * x * x * width + twist * q.x
            return base + d * q.y + side * q.x + up * (q.z + h)
        }
        return RecipeMesh.outward(b)
    }

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        let L = stemLength, sr: Float = 0.0014
        let bend = rng.float(-0.006...0.006)
        let stemPath: [V3] = (0...8).map { i in
            let t = Float(i) / 8
            return V3(t * L, sr + 0.0004 * sin(t * 3), bend * sin(.pi * t))
        }
        // Square-ish section (superellipse) tapering to the tip.
        let stemS = RecipeMesh.sweep(stemPath, edge: 0.002, endBulge: 0.2, seamTile: 0.02, material: stem) { t, a in
            let r = sr * (1 - 0.45 * t)
            let c = abs(cos(a)), s = abs(sin(a)), e: Float = 3.2
            return r / pow(pow(c, e) + pow(s, e), 1 / e)
        }
        var m = Model(name: Self.id)
        m.add(stemS)
        var leaves = Surface(material: leaf)
        var stems = Surface(material: stem)
        // Nodes: (position along the stem, leaf length factor, pair angle from the stem).
        let nodes: [(Float, Float, Float)] = [(0.36, 1.0, 1.0), (0.66, 0.78, 0.75), (0.93, 0.42, 0.45)]
        for (k, nd) in nodes.enumerated() {
            let x = nd.0 * L
            let p = V3(x, sr + 0.0004 * sin(nd.0 * 3), bend * sin(.pi * nd.0))
            for sgn in [Float(-1), 1] {
                var r = rng.fork(k * 2 + (sgn > 0 ? 1 : 0))
                let ang = nd.2 * sgn + r.float(-0.12...0.12)
                let dir = V3(cos(ang), 0, sin(ang))
                let len = leafLength * nd.1 * r.float(0.9...1.05)
                // Petiole.
                let pe = p + dir * 0.006 + V3(0, 0.0012, 0)
                stems.append(FoodMesh.tube([p, (p + pe) / 2 + V3(0, 0.0006, 0), pe], radii: [0.0008, 0.0006, 0.0005], sides: 6,
                                           endBulge: 0.3, material: stem))
                let w = len * r.float(0.27...0.32)
                leaves.append(Self.leafShell(length: len, width: w, base: pe, dir: dir, lift: 0.0026, cup: 0.12 + 0.06 * Float(k),
                                             droop: 0.003 + 0.002 * Float(k), material: leaf, rng: &r))
            }
        }
        // Tip bud: two tiny folded leaves pointing forward.
        let tip = stemPath[8]
        for sgn in [Float(-1), 1] {
            var r = rng.fork(40 + Int(sgn))
            let dir = V3(1, 0, 0.25 * sgn)
            leaves.append(Self.leafShell(length: 0.013, width: 0.0035, base: tip - V3(0.002, 0, 0), dir: dir, lift: 0.0018,
                                         cup: 0.35, droop: 0.002, material: leaf, rng: &r))
        }
        m.add(stems)
        m.add(leaves)
        let b = m.bounds
        m = m.transformed(Xform(translation: V3(-(b.min.x + b.max.x) / 2, -b.min.y, -(b.min.z + b.max.z) / 2)))
        groundAO(&m, height: 0.006, floor: 0.7)
        return LODModel(m)
    }
}
