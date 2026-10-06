import simd
import Foundation

/// Deli-style cheddar slice, 9 x 9 cm and 3 mm thick, lying flat with a slight droop and one corner
/// lifting. One closed rounded slab subdivided evenly so it bends without facets. Cook kind
/// `dairy`: melts glossy toward `food.cheddar-melted`.
public struct CheddarSlice: RealFood {
    public static let id = "cheddar-slice"
    public static let summary = "Cheddar slice, 9 x 9 cm x 3 mm: orange processed cheddar with soft edges; melts glossy."
    public static let tags = ["prop", "food", "kitchen", "handheld"]
    public static let budget = 6000
    public static let author = "realityhd"
    public static let kind = FoodKind.dairy
    public static let preview = PreviewHint(azimuth: 30, elevation: 45, distance: 0.25, studio: true)

    /// Side length (m).
    public var side: Float = 0.09
    /// Thickness (m).
    public var thickness: Float = 0.003
    /// Material key.
    public var cheese: MaterialKey = "food.cheddar"
    public init() {}

    public var coreCenter: V3 { V3(0, thickness / 2, 0) }

    public func capMaterial(for key: MaterialKey) -> MaterialKey? { key == cheese ? cheese : nil }

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        let h = side / 2, T = thickness
        var s = FoodMesh.box(V3(side * rng.float(0.99...1.01), T, side), radius: 0.0009, edge: 0.0042, bevelSegments: 2, material: cheese)
        let lift = rng.float(0.002...0.004), sd = UInt32(truncatingIfNeeded: seed)
        let cx: Float = rng.float() < 0.5 ? 1 : -1
        s.deform { p in
            var q = p
            q.y += T / 2
            // Corner lift (one corner peels up) and a faint wave.
            let c = max(0, (cx * p.x + p.z) / (2 * h) - 0.4) / 0.6
            q.y += lift * c * c
            q.y += 0.0003 * RecipeMesh.noise(V3(p.x, 0, p.z), 25, seed: sd)
            return q
        }
        var m = Model(name: Self.id)
        m.add(s)
        let b = m.bounds
        m = m.transformed(Xform(translation: V3(0, -b.min.y, 0)))
        groundAO(&m, height: 0.004, floor: 0.75)
        return LODModel(m)
    }
}
