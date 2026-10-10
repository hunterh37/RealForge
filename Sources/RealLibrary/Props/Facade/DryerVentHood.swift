import simd
import Foundation

/// Dryer exhaust vent hood: square 0.16 m wall plate, a 100 mm round duct stub, a louvered hood with a
/// gravity flap and a lint-caught bird guard, in powder-coated aluminum. Wall plane at z = 0.
public struct DryerVentHood: RealAsset {
    public static let id = "dryer-vent-hood"
    public static let summary = "Dryer vent hood, 0.16 m plate: 100 mm duct stub, louvered hood with gravity flap, caulk bead, screws."
    public static let tags = ["prop", "architecture", "facade", "metal"]
    public static let budget = 4000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 30, elevation: 14, distance: 0.7)

    public var shell: MaterialKey = "metal.powder-white"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let c: Float = 0.1
        FA.box(&m, V3(0.16, 0.16, 0.012), V3(0, c, 0.006), shell, r: 0.004)
        for (x, y) in [(-0.065, -0.065), (0.065, -0.065), (-0.065, 0.065), (0.065, 0.065)] as [(Float, Float)] {
            hexBolt(&m, at: V3(x, c + y, 0.012), normal: FA.Z, size: 0.008, material: "metal.screw-zinc")
        }
        FA.cylZ(&m, r: 0.053, h: 0.05, at: V3(0, c, 0.01), shell, bevel: 0.002, segments: 22)
        // Hood shell: lathe cut to a half dome facing down.
        m.add(Prim.extrude([V2(-0.075, 0), V2(0.075, 0), V2(0.075, 0.04), V2(0.04, 0.085), V2(-0.04, 0.085), V2(-0.075, 0.04)], depth: 0.06,
                           bevel: 0.004, bevelSegments: 1, material: shell),
              Xform(translation: V3(0, c + 0.02, 0.06), rotation: .identity))
        FA.box(&m, V3(0.15, 0.012, 0.09), V3(0, c - 0.05, 0.06), shell, r: 0.003, rot: FA.q(-8, FA.X))
        // Louver slats and gravity flap behind them.
        for i in 0..<4 {
            let y = c - 0.04 + Float(i) * 0.016
            FA.box(&m, V3(0.11, 0.005, 0.03), V3(0, y, 0.101), "metal.aluminum-brushed", r: 0.001, rot: FA.q(-30, FA.X))
        }
        FA.box(&m, V3(0.08, 0.07, 0.003), V3(0, c, 0.062), "plastic.black", r: 0.001, rot: FA.q(-12, FA.X))
        // Caulk bead around the plate and a lint wisp.
        for (p, s) in [(V3(0, c + 0.082, 0.014), V3(0.17, 0.004, 0.004)), (V3(0, c - 0.082, 0.014), V3(0.17, 0.004, 0.004)),
                       (V3(-0.082, c, 0.014), V3(0.004, 0.17, 0.004)), (V3(0.082, c, 0.014), V3(0.004, 0.17, 0.004))] {
            FA.box(&m, s, p, "plastic.white", r: 0.0015)
        }
        m.add(Prim.superellipsoid(V3(0.05, 0.02, 0.02), exponent: 2, subdivisions: 4, material: "fabric.linen"),
              Xform(translation: V3(rng.float(-0.01...0.01), c - 0.06, 0.1)))
        groundAO(&m, height: 0.06, floor: 0.9)
        return LODModel(FC.place(m))
    }
}
