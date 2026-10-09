import simd
import Foundation

public struct TireSwing: RealAsset {
    public static let id = "tire-swing"
    public static let summary = "Tire swing on 2 m chain: used car tire 0.65 m diameter hung from three galvanized chain legs and ring."
    public static let tags = ["prop", "landscaping", "outdoor", "playground"]
    public static let budget = 6000
    public static let author = "realityhd"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        m.add(Prim.torus(major: 0.23, minor: 0.1, segments: 32, sides: 12, material: "rubber.tire"), Xform(translation: V3(0, 0.1, 0)))
        m.add(Prim.torus(major: 0.04, minor: 0.006, segments: 12, sides: 6, material: "metal.galvanized"), Xform(translation: V3(0, 2.0, 0)))
        for i in 0..<3 {
            let a = Float(i) / 3 * 2 * .pi
            K.rod(&m, [V3(cos(a) * 0.23, 0.18, sin(a) * 0.23), V3(0, 1.98, 0)], r: 0.005, "metal.galvanized", sides: 6)
        }
        return K.finish(&m)
    }
}
