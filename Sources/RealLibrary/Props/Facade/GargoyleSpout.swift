import simd
import Foundation

/// Carved gargoyle water spout: a stone grotesque projecting 0.65 m from the wall on a flared base,
/// with brow ridge, horns, ears, open mouth, back spine and a dark bore. Wall plane at z = 0.
public struct GargoyleSpout: RealAsset {
    public static let id = "gargoyle-spout"
    public static let summary = "Gothic gargoyle spout, 0.65 m projection: carved limestone grotesque with horns, brow, open mouth and spine."
    public static let tags = ["prop", "architecture", "facade", "ornament", "stone"]
    public static let budget = 7000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 55, elevation: 12, distance: 1.9)

    public var length: Float = 0.65
    public var stone: MaterialKey = "stone.limestone-sooted"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let L = length, y0: Float = 0.3
        m.add(Prim.tube([V3(0, y0, 0), V3(0, y0 + 0.01, 0.2), V3(0, y0 - 0.02, L * 0.6)], radii: [0.17, 0.13, 0.11], sides: 14, seamTile: 0.3, material: stone))
        // Flared wall base.
        FA.box(&m, V3(0.4, 0.4, 0.07), V3(0, y0, 0.035), stone, r: 0.012)
        // Skull, snout and jaw.
        m.add(Prim.superellipsoid(V3(0.24, 0.24, 0.26), exponent: 2.6, subdivisions: 9, material: stone), Xform(translation: V3(0, y0 + 0.02, L * 0.72)))
        m.add(Prim.superellipsoid(V3(0.17, 0.12, 0.2), exponent: 2.8, subdivisions: 8, material: stone), Xform(translation: V3(0, y0 - 0.02, L - 0.07)))
        m.add(Prim.superellipsoid(V3(0.15, 0.06, 0.2), exponent: 3, subdivisions: 6, material: stone),
              Xform(translation: V3(0, y0 - 0.14, L - 0.1), rotation: FA.q(-14, FA.X)))
        FA.box(&m, V3(0.1, 0.05, 0.1), V3(0, y0 - 0.07, L - 0.04), "metal.rust", r: 0.01)
        // Teeth.
        for k in -2...2 {
            let x = Float(k) * 0.026
            m.add(Prim.lathe([V2(0.011, 0), V2(0.006, 0.02), V2(0, 0.036)], segments: 6, material: "stone.limestone"),
                  Xform(translation: V3(x, y0 - 0.052, L - 0.01), rotation: FA.q(180, FA.Z)))
        }
        // Brow ridge and eyes.
        FA.box(&m, V3(0.26, 0.03, 0.06), V3(0, y0 + 0.1, L * 0.78), stone, r: 0.012, rot: FA.q(8, FA.X))
        for s: Float in [-1, 1] {
            m.add(Prim.superellipsoid(V3(0.05, 0.045, 0.04), exponent: 2, subdivisions: 6, material: "stone.limestone"), Xform(translation: V3(s * 0.065, y0 + 0.065, L * 0.8)))
            // Horns and ears.
            m.add(Prim.lathe([V2(0.03, 0), V2(0.018, 0.1), V2(0.004, 0.22)], segments: 8, material: stone),
                  Xform(translation: V3(s * 0.09, y0 + 0.13, L * 0.68), rotation: FA.q(s * -24, FA.Z) * FA.q(-18, FA.X)))
            m.add(Prim.superellipsoid(V3(0.012, 0.1, 0.06), exponent: 2.4, subdivisions: 6, material: stone),
                  Xform(translation: V3(s * 0.135, y0 + 0.04, L * 0.64), rotation: FA.q(s * 20, FA.Z)))
            // Folded wing stub.
            m.add(Prim.superellipsoid(V3(0.04, 0.2, 0.3), exponent: 2.5, subdivisions: 7, material: stone),
                  Xform(translation: V3(s * 0.16, y0 + 0.1, 0.22), rotation: FA.q(s * -14, FA.Z)))
        }
        // Spine ridge along the back.
        for i in 0..<6 {
            let z = 0.1 + Float(i) * 0.075
            m.add(Prim.lathe([V2(0.022, 0), V2(0.012, 0.03), V2(0, 0.06)], segments: 6, material: stone),
                  Xform(translation: V3(0, y0 + 0.12 - Float(i) * 0.004 + rng.float(-0.003...0.003), z)))
        }
        groundAO(&m, height: 0.2, floor: 0.8)
        return LODModel(FC.place(m))
    }
}
