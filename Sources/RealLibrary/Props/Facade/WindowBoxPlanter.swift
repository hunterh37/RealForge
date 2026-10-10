import simd
import Foundation

/// Window box planter: a cedar box of 18 mm boards on two iron brackets, potting soil, geranium leaf
/// clusters and red blooms spilling over the front. One bracket screw is rusted.
public struct WindowBoxPlanter: RealAsset {
    public static let id = "window-box-planter"
    public static let summary = "Cedar window box, 1 m: slatted box on iron brackets, soil, geranium foliage and red blooms."
    public static let tags = ["prop", "architecture", "facade", "landscaping", "wood", "garden"]
    public static let budget = 10_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 30, elevation: 18, distance: 1.2)

    public var length: Float = 1.0
    public var boxHeight: Float = 0.2
    public var boxDepth: Float = 0.22
    public var wood: MaterialKey = "wood.cedar-weathered"
    public var iron: MaterialKey = "metal.wrought-iron"
    public var bloom: MaterialKey = "flower.petal:C4202A"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let L = length, H = boxHeight, D = boxDepth, t: Float = 0.018, y0: Float = 0.1
        FA.box(&m, V3(L, H, t), V3(0, y0 + H / 2, D - t / 2), wood, r: 0.003)
        FA.box(&m, V3(L, H, t), V3(0, y0 + H / 2, t / 2), wood, r: 0.003)
        for e: Float in [-1, 1] { FA.box(&m, V3(t, H, D - 2 * t + 0.004), V3(e * (L / 2 - t / 2), y0 + H / 2, D / 2), wood, r: 0.003) }
        FA.box(&m, V3(L - 2 * t, t, D - 2 * t), V3(0, y0 + t / 2, D / 2), wood, r: 0.002)
        for x in [-L * 0.32, L * 0.32] {
            FA.box(&m, V3(0.025, 0.008, D), V3(x, y0 - 0.004, D / 2), iron, r: 0.002)
            FA.box(&m, V3(0.025, y0 + 0.03, 0.008), V3(x, (y0 + 0.03) / 2, 0.004), iron, r: 0.002)
            FA.rod(&m, V3(x, 0.01, 0.01), V3(x, y0 - 0.01, D - 0.02), r: 0.006, iron, sides: 8)
            hexBolt(&m, at: V3(x, y0 * 0.6, 0.009), normal: FA.Z, size: 0.012, material: "metal.rust")
        }
        // Soil and plants.
        m.add(Prim.superellipsoid(V3(L - 2 * t - 0.01, 0.07, D - 2 * t - 0.01), exponent: 6, subdivisions: 8, material: "soil.potting"),
              Xform(translation: V3(0, y0 + H - 0.025, D / 2)))
        for i in 0..<7 {
            let x = -L / 2 + 0.1 + Float(i) * (L - 0.2) / 6
            let z = D / 2 + rng.float(-0.04...0.04)
            let h = rng.float(0.1...0.17)
            for k in 0..<3 {
                let a = Float(k) * 120 + rng.float(0...60), lean = rng.float(10...35)
                m.add(Prim.superellipsoid(V3(0.13, 0.025, 0.11), exponent: 2.5, subdivisions: 4, material: "leaf.plain"),
                      Xform(translation: V3(x + 0.03 * cos(a * .pi / 180), y0 + H + 0.02 + h * 0.25, z + 0.03 * sin(a * .pi / 180)),
                            rotation: FA.q(a, FA.Y) * FA.q(lean, FA.Z)))
            }
            FA.rod(&m, V3(x, y0 + H + 0.005, z), V3(x, y0 + H + h, z), r: 0.004, "plant.stem", sides: 5)
            m.add(Prim.superellipsoid(V3(0.07, 0.06, 0.07), exponent: 2, subdivisions: 4, material: bloom),
                  Xform(translation: V3(x + rng.float(-0.02...0.02), y0 + H + h + 0.025, z + rng.float(-0.02...0.03))))
        }
        // Trailing ivy over the front board.
        for i in 0..<5 {
            let x = rng.float(-0.4...0.4)
            m.add(Prim.superellipsoid(V3(0.1, 0.1, 0.02), exponent: 2.5, subdivisions: 4, material: "leaf.plain"),
                  Xform(translation: V3(x, y0 + H - 0.03 - rng.float(0...0.06), D + 0.005), rotation: FA.q(rng.float(-20...20), FA.Z)))
        }
        groundAO(&m, height: 0.1, floor: 0.75)
        return LODModel(FA.centerZ(m))
    }
}
