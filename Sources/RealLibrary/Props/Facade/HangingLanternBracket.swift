import simd
import Foundation

/// Hanging lantern on a scroll bracket: a wall-mounted wrought-iron arm with a rolled scroll brace
/// carries a 0.45 m tall four-pane glass lantern with brass cap, finial and a candle flame.
public struct HangingLanternBracket: RealAsset {
    public static let id = "hanging-lantern-bracket"
    public static let summary = "Scroll-arm bracket with hanging 0.45 m four-pane glass lantern, brass cap and candle flame."
    public static let tags = ["prop", "architecture", "facade", "light", "metal", "glass"]
    public static let budget = 9_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 30, elevation: 10, distance: 2.4)

    public var armLength: Float = 0.7
    public var iron: MaterialKey = "metal.wrought-iron"
    public var brass: MaterialKey = "metal.brass-aged"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let L = armLength, top: Float = 1.0
        FA.box(&m, V3(0.1, 0.5, 0.014), V3(0, top - 0.1, 0.007), iron, r: 0.003)
        for dy: Float in [-0.14, 0.14] { hexBolt(&m, at: V3(0, top - 0.1 + dy, 0.015), normal: FA.Z, size: 0.014, material: "metal.rust") }
        FA.rod(&m, V3(0, top, 0.014), V3(0, top, L), r: 0.011, iron)
        FA.path(&m, catmull([V3(0, top - 0.32, 0.014), V3(0, top - 0.2, L * 0.3), V3(0, top - 0.06, L * 0.65), V3(0, top, L * 0.8)], per: 8), r: 0.008, iron, sides: 8)
        m.add(Prim.torus(major: 0.045, minor: 0.006, segments: 20, sides: 6, material: iron), Xform(translation: V3(0, top - 0.08, L * 0.45 - 0.01), rotation: FA.q(90, FA.Z)))
        FA.path(&m, catmull([V3(0, top, L), V3(0, top + 0.05, L - 0.04), V3(0, top + 0.02, L - 0.08)], per: 6), r: 0.007, iron, sides: 6)
        // Chain and lantern.
        let lx = L - 0.01
        m.add(chain(along: [V3(0, top - 0.02, lx), V3(0, top - 0.12, lx)], wire: 0.004, material: iron))
        let ly = top - 0.14
        m.add(Prim.lathe([V2(0.0, 0.0), V2(0.07, 0.0), V2(0.1, 0.03), V2(0.11, 0.07), V2(0.0, 0.09)], segments: 4, material: brass), Xform(translation: V3(0, ly - 0.09, lx), rotation: FA.q(45, FA.Y)))
        FA.ball(&m, r: 0.018, at: V3(0, ly + 0.0, lx), brass)
        let h: Float = 0.36, hw: Float = 0.09
        let by = ly - 0.09 - h
        for sx: Float in [-1, 1] { for sz: Float in [-1, 1] { FA.rod(&m, V3(sx * hw, by, lx + sz * hw), V3(sx * hw, by + h, lx + sz * hw), r: 0.007, brass, sides: 6) } }
        for (dx, dz, w, d) in [(0.0, hw, 2 * hw, 0.003), (0.0, -hw, 2 * hw, 0.003), (hw, 0.0, 0.003, 2 * hw), (-hw, 0.0, 0.003, 2 * hw)] as [(Float, Float, Float, Float)] {
            m.add(Prim.roundedBox(V3(w, h - 0.02, d), radius: 0.001, bevelSegments: 1, material: "glass.clear"), Xform(translation: V3(dx, by + h / 2, lx + dz)))
        }
        FA.box(&m, V3(2 * hw + 0.02, 0.025, 2 * hw + 0.02), V3(0, by - 0.005, lx), brass, r: 0.003)
        FA.cylZ(&m, r: 0.012, h: 0.1, at: V3(0, by + 0.02, lx), "ceramic.bisque", segments: 8)
        m.add(Prim.superellipsoid(V3(0.02, 0.05, 0.02), exponent: 2, subdivisions: 4, material: "emissive.warm"), Xform(translation: V3(0, by + 0.19, lx)))
        groundAO(&m, height: 0.1, floor: 0.9)
        return LODModel(FC.seatY(m))
    }
}
