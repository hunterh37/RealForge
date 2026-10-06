import simd
import Foundation

/// 8 inch (20 cm) flour tortilla lying flat: a thin 2 mm round slab with a soft wavy rim and a
/// gentle sag, planar UVs so the flour specks and griddle spots of `food.tortilla` sit flat. Cook
/// kind `batter`: browns with blistered spots toward `food.tortilla-cooked`.
public struct FlourTortilla: RealFood {
    public static let id = "flour-tortilla"
    public static let summary = "Flour tortilla, 20 cm: thin soft flatbread, wavy edge, pale with light toast spots; browns with blisters."
    public static let tags = ["prop", "food", "kitchen", "handheld"]
    public static let budget = 6000
    public static let author = "realityhd"
    public static let kind = FoodKind.batter
    public static let preview = PreviewHint(azimuth: 25, elevation: 40, distance: 0.45, studio: true)

    /// Diameter (m).
    public var diameter: Float = 0.2
    /// Thickness (m).
    public var thickness: Float = 0.002
    /// Material key.
    public var dough: MaterialKey = "food.tortilla"
    public init() {}

    public var coreCenter: V3 { V3(0, thickness / 2, 0) }

    public func capMaterial(for key: MaterialKey) -> MaterialKey? { key == dough ? dough : nil }

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        let R = diameter / 2
        let ph = (0..<4).map { _ in rng.float(0...6.28) }
        let outline = RecipeMesh.loop(count: 256) { a in R * (1 + 0.012 * sin(3 * a + ph[0]) + 0.006 * sin(7 * a + ph[1])) }
        var s = RecipeMesh.slab(outline: outline, thickness: thickness, bevel: 0.0009, edge: 0.0068, bevelSegments: 2, material: dough)
        let sd = UInt32(truncatingIfNeeded: seed)
        s.deform { p in
            let r = simd_length(V2(p.x, p.z)) / R, a = atan2(p.z, p.x)
            let rim = smoothstep(0.55, 1.0, r)
            let wave = 0.0028 * rim * (0.5 + 0.5 * sin(4 * a + ph[2])) * (0.7 + 0.3 * sin(9 * a + ph[3]))
            let bump = 0.0006 * RecipeMesh.noise(V3(p.x, 0, p.z), 18, seed: sd) * (1 - rim)
            return V3(p.x, p.y + wave + max(0, bump), p.z)
        }
        s = FoodMesh.planarUV(s)
        var m = Model(name: Self.id)
        m.add(s)
        let b = m.bounds
        m = m.transformed(Xform(translation: V3(0, -b.min.y, 0)))
        groundAO(&m, height: 0.004, floor: 0.75)
        return LODModel(m)
    }
}
