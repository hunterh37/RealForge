import simd
import Foundation

public struct Clothesline: RealAsset {
    public static let id = "clothesline"
    public static let summary = "Rotary clothesline, 1.8 m: galvanized post, four-arm folding frame and 24 m of white cord."
    public static let tags = ["prop", "landscaping", "outdoor", "metal"]
    public static let budget = 6000
    public static let author = "realityhd"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let g = "metal.galvanized"
        K.rod(&m, [V3(0, 0, 0), V3(0, 1.75, 0)], r: 0.022, g, sides: 12)
        m.add(Prim.cylinder(radius: 0.045, height: 0.05, bevel: 0.004, segments: 16, material: g), Xform(translation: V3(0, 1.75, 0)))
        for a in 0..<4 {
            let t = Float(a) * .pi / 2, c = cos(t), s = sin(t)
            K.rod(&m, [V3(0, 1.77, 0), V3(c * 0.9, 1.9, s * 0.9)], r: 0.008, g, sides: 6)
            K.rod(&m, [V3(0, 1.77, 0), V3(c * 0.45, 1.84, s * 0.45)], r: 0.003, g, sides: 4)
        }
        for r: Float in [0.3, 0.55, 0.8] {
            K.rod(&m, (0...24).map { i in let a = Float(i) / 24 * 2 * .pi; return V3(cos(a) * r, 1.79 + r * 0.13, sin(a) * r) }, r: 0.0015, "fabric.webbing", sides: 4)
        }
        return K.finish(&m)
    }
}
