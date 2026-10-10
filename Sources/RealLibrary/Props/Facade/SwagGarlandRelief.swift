import simd
import Foundation

/// Neoclassical swag frieze, 2.1 m: a cast-stone band carrying three hanging fruit-and-leaf swags looped
/// between rosette paterae, with ribbon ties and tassels. Wall plane at z = 0.
public struct SwagGarlandRelief: RealAsset {
    public static let id = "swag-garland-relief"
    public static let summary = "Neoclassical swag frieze, 2.1 m: stone band, three fruit-and-leaf swags, rosettes, ribbons, tassels."
    public static let tags = ["prop", "architecture", "facade", "trim", "ornament", "stone"]
    public static let budget = 8000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 22, elevation: 8, distance: 3.2)

    public var length: Float = 2.1
    public var band: Float = 0.5
    public var stone: MaterialKey = "stone.cast-stone"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let L = length, H = band, n = 3, span = L / Float(n)
        FA.box(&m, V3(L, H, 0.04), V3(0, H / 2, 0.02), stone, r: 0.006)
        FA.box(&m, V3(L + 0.04, 0.03, 0.06), V3(0, H - 0.015, 0.03), stone, r: 0.006)
        FA.box(&m, V3(L + 0.04, 0.03, 0.06), V3(0, 0.015, 0.03), stone, r: 0.006)
        for i in 0...n {
            let x = -L / 2 + Float(i) * span
            FA.cylZ(&m, r: 0.05, h: 0.03, at: V3(x, H * 0.78, 0.04), stone, bevel: 0.004, segments: 14)
            for k in 0..<6 {
                let a = Float(k) / 6 * 2 * .pi
                m.add(Prim.superellipsoid(V3(0.028, 0.022, 0.012), exponent: 2, subdivisions: 2, material: stone),
                      Xform(translation: V3(x + cos(a) * 0.034, H * 0.78 + sin(a) * 0.034, 0.075), rotation: FA.q(a * 180 / .pi, FA.Z)))
            }
            FC.bead(&m, r: 0.016, at: V3(x, H * 0.78, 0.085), stone)
        }
        for i in 0..<n {
            let x0 = -L / 2 + Float(i) * span + 0.05, x1 = x0 + span - 0.1
            let steps = 14
            var pts: [V3] = [], radii: [Float] = []
            for k in 0...steps {
                let t = Float(k) / Float(steps)
                pts.append(V3(x0 + (x1 - x0) * t, H * 0.78 - sin(t * .pi) * 0.26, 0.07))
                radii.append(0.014 + 0.03 * sin(t * .pi))
            }
            m.add(Prim.tube(pts, radii: radii, sides: 6, seamTile: 0.1, material: stone))
            for k in 1..<steps {
                let p = pts[k], t = Float(k) / Float(steps)
                if k % 2 == 0 {
                    m.add(Prim.superellipsoid(V3(0.05, 0.026, 0.014), exponent: 2.2, subdivisions: 2, material: stone),
                          Xform(translation: p + V3(0, 0.02, 0.025), rotation: FA.q(rng.float(-40...40) + (t - 0.5) * 60, FA.Z)))
                } else {
                    FC.bead(&m, r: 0.015 + 0.006 * sin(t * .pi), at: p + V3(rng.float(-0.005...0.005), -0.02, 0.022), stone)
                }
            }
            // Tassel drop at the lowest point.
            let mid = pts[steps / 2]
            m.add(Prim.lathe([V2(0.0, 0), V2(0.012, 0.01), V2(0.016, 0.05), V2(0.004, 0.09), V2(0, 0.1)], segments: 8, material: stone),
                  Xform(translation: mid + V3(0, -0.12, 0.03)))
        }
        groundAO(&m, height: 0.1, floor: 0.9)
        return LODModel(FC.place(m))
    }
}
