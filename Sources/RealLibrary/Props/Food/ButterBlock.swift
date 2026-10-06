import simd
import Foundation

/// Half-cup (one US stick, 113 g) butter block lying along +X: a closed rounded box with edges
/// softened by handling, shallow wrapper fold impressions across the faces, a slight sag, and one end
/// cut at a small angle with a knife. Cut face `food.butter`; browns to `food.butter-cooked`.
public struct ButterBlock: RealFood {
    public static let id = "butter-block"
    public static let summary = "Half-cup butter stick, 12 x 3.2 x 3.2 cm: pale yellow block with softened edges and wrapper impressions."
    public static let tags = ["prop", "food", "kitchen", "handheld"]
    public static let budget = 4000
    public static let author = "realityhd"
    public static let kind = FoodKind.dairy
    public static let preview = PreviewHint(azimuth: 30, elevation: 30, distance: 0.3, studio: true)

    /// Block size (m).
    public var size = V3(0.121, 0.032, 0.032)
    /// Edge radius (m).
    public var edgeRadius: Float = 0.0028
    /// Material key.
    public var butter: MaterialKey = "food.butter"
    public init() {}

    public var coreCenter: V3 { V3(0, size.y / 2, 0) }

    public func capMaterial(for key: MaterialKey) -> MaterialKey? { key == butter ? butter : nil }

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        let folds = (0..<4).map { _ in rng.float(-0.05...0.05) }
        var s = FoodMesh.box(size, radius: edgeRadius, edge: 0.0042, extra: [folds, [], []], material: butter)
        let h = size / 2
        let cut = rng.float(-0.08...0.08), ph = rng.float(0...6.28)
        s.deform { p in
            var q = p
            // Wrapper fold impressions: shallow grooves across the top and sides.
            for f in folds { q -= simd_normalize(V3(0, p.y, p.z) + V3(0, 1e-6, 0)) * 0.0005 * exp(-pow((p.x - f) / 0.0009, 2)) }
            // Slight sag of a softened stick and bulging sides.
            q.y -= 0.0006 * (1 - pow(p.x / h.x, 2)) * (p.y / h.y + 1) * 0.5
            q.z *= 1 + 0.005 * (1 - pow(p.y / h.y, 2))
            // A knife scrape taken off the top near the cut end: a shallow scoop with ridges.
            let top = smoothstep(h.y * 0.6, h.y, p.y)
            let dx = (p.x - h.x * 0.55) / 0.011, dz = (p.z - h.z * 0.15) / 0.009
            let scoop = exp(-(dx * dx + dz * dz))
            q.y -= top * scoop * (0.0024 + 0.0003 * sin(p.x * 900))
            // Knife-cut end at +X, slightly angled and wavy.
            if p.x > h.x - 0.004 { q.x += cut * p.z + 0.0003 * sin(p.y * 400 + ph) }
            return q
        }
        var m = Model(name: Self.id)
        m.add(s)
        m = m.transformed(Xform(translation: V3(0, h.y, 0)))
        let bb = m.bounds
        m = m.transformed(Xform(translation: V3(0, -bb.min.y, 0)))
        groundAO(&m, height: 0.008, floor: 0.6)
        return LODModel(m)
    }
}
