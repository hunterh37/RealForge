import simd
import Foundation

/// Projecting blade sign: a wall plate, a scrolled wrought iron arm with a diagonal brace, two hanger
/// rods and a painted double-sided panel with a brass border and medallions.
public struct BladeSign: RealAsset {
    public static let id = "blade-sign"
    public static let summary = "Projecting blade sign, 0.9 m bracket: scroll iron arm, two hanging rods, double-sided painted panel."
    public static let tags = ["prop", "architecture", "facade", "street", "sign", "metal", "urban"]
    public static let budget = 9_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 55, elevation: 8, distance: 1.9)

    public var arm: Float = 0.9
    public var armHeight: Float = 0.65
    public var panelSize = V2(0.6, 0.5)
    public var iron: MaterialKey = "metal.wrought-iron"
    public var face: MaterialKey = "wood.painted-shaker-worn:7A1F1F"
    public var trim: MaterialKey = "metal.brass-aged"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let A = arm, Y = armHeight, pw = panelSize.x, ph = panelSize.y
        FA.box(&m, V3(0.1, 0.34, 0.012), V3(0, Y - 0.1, 0.006), iron, r: 0.002)
        for dy: Float in [-0.07, 0.07] { hexBolt(&m, at: V3(0, Y - 0.1 + dy * 2, 0.013), normal: FA.Z, size: 0.014, material: "metal.rust") }
        FA.rod(&m, V3(0, Y, 0.012), V3(0, Y, A), r: 0.012, iron)
        FA.ball(&m, r: 0.022, at: V3(0, Y, A + 0.01), iron)
        FA.path(&m, [V3(0, Y - 0.34, 0.012), V3(0, Y - 0.25, A * 0.35), V3(0, Y - 0.06, A * 0.82), V3(0, Y - 0.012, A * 0.97)], r: 0.008, iron, sides: 8)
        m.add(Prim.torus(major: 0.07, minor: 0.007, segments: 24, sides: 6, material: iron),
              Xform(translation: V3(0, Y - 0.1, A * 0.55), rotation: FA.q(90, FA.Z)))
        // Hangers and panel.
        let z0: Float = 0.22, z1: Float = z0 + pw, top: Float = Y - 0.012, py: Float = top - 0.12 - ph / 2
        for z in [z0 + 0.05, z1 - 0.05] { FA.rod(&m, V3(0, top, z), V3(0, py + ph / 2, z), r: 0.004, iron, sides: 6) }
        FA.box(&m, V3(0.04, ph, pw), V3(0, py, (z0 + z1) / 2), face, r: 0.004)
        for (dz, dy, w, h) in [(0.0, ph / 2, pw + 0.02, 0.018), (0.0, -ph / 2, pw + 0.02, 0.018)] as [(Float, Float, Float, Float)] {
            FA.box(&m, V3(0.05, h, w), V3(0, py + dy, (z0 + z1) / 2 + dz), trim, r: 0.003)
        }
        for dz: Float in [-pw / 2, pw / 2] { FA.box(&m, V3(0.05, ph, 0.018), V3(0, py, (z0 + z1) / 2 + dz), trim, r: 0.003) }
        for e: Float in [-1, 1] {
            m.add(Prim.torus(major: 0.11, minor: 0.008, segments: 28, sides: 6, material: trim),
                  Xform(translation: V3(e * 0.022, py, (z0 + z1) / 2), rotation: FA.q(90, FA.Z)))
            m.add(Prim.superellipsoid(V3(0.014, 0.12, 0.12), exponent: 2, subdivisions: 8, material: trim), Xform(translation: V3(e * 0.024, py, (z0 + z1) / 2 + rng.float(-0.002...0.002))))
        }
        groundAO(&m, height: 0.1, floor: 0.9)
        return LODModel(FA.centerZ(m))
    }
}
