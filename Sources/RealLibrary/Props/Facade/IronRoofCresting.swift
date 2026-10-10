import simd
import Foundation

/// Victorian iron ridge cresting, 2.4 m run: base rail on cast shoes, repeating anthemion scrolls every
/// 0.3 m and a spiked finial between each, with a continuous top bead. Sits on y = 0.
public struct IronRoofCresting: RealAsset {
    public static let id = "iron-roof-cresting"
    public static let summary = "Victorian ridge cresting, 2.4 m: cast shoes, base rail, scrolled anthemion repeats, spiked finials."
    public static let tags = ["prop", "architecture", "facade", "roof", "ornament", "metal"]
    public static let budget = 6500
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 30, elevation: 12, distance: 3.6)

    public var length: Float = 2.4
    public var pitch: Float = 0.3
    public var iron: MaterialKey = "metal.wrought-iron"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let L = length, n = Int(L / pitch), x0 = -L / 2
        FA.box(&m, V3(L, 0.03, 0.02), V3(0, 0.08, 0), iron, r: 0.003)
        FA.box(&m, V3(L, 0.015, 0.016), V3(0, 0.46, 0), iron, r: 0.002)
        for i in 0...n {
            let x = x0 + Float(i) * pitch
            FA.box(&m, V3(0.06, 0.07, 0.05), V3(x, 0.035, 0), iron, r: 0.005)
            FA.rod(&m, V3(x, 0.07, 0), V3(x, 0.44, 0), r: 0.008, iron, sides: 6)
            m.add(Prim.lathe([V2(0.008, 0), V2(0.014, 0.012), V2(0.004, 0.06), V2(0, 0.1)], segments: 6, material: iron), Xform(translation: V3(x, 0.46 + rng.float(-0.002...0.002), 0)))
            FC.bead(&m, r: 0.016, at: V3(x, 0.3, 0), iron)
        }
        for i in 0..<n {
            let cx = x0 + (Float(i) + 0.5) * pitch
            // Heart scroll pair between uprights.
            for s: Float in [-1, 1] {
                var pts: [V3] = []
                for k in 0...10 {
                    let t = Float(k) / 10, a = t * 2.6 * .pi, r = 0.06 * (1 - t * 0.7)
                    pts.append(V3(cx + s * (0.055 + r * cos(a)), 0.2 + r * sin(a) + t * 0.06, 0))
                }
                FA.path(&m, pts, r: 0.0055, iron, sides: 4)
            }
            FA.path(&m, [V3(cx, 0.095, 0), V3(cx, 0.3, 0), V3(cx, 0.4, 0)], r: 0.005, iron, sides: 4)
            m.add(Prim.superellipsoid(V3(0.05, 0.1, 0.012), exponent: 2.2, subdivisions: 3, material: iron), Xform(translation: V3(cx, 0.36, 0)))
        }
        groundAO(&m, height: 0.1, floor: 0.85)
        return LODModel(m)
    }
}
