import simd
import Foundation

public struct Trampoline: RealAsset {
    public static let id = "trampoline"
    public static let summary = "Round backyard trampoline, 3.0 m: steel frame, 6 legs, black mat, 72 springs ring and blue pad."
    public static let tags = ["prop", "landscaping", "outdoor", "playground", "metal"]
    public static let budget = 12000
    public static let author = "realityhd"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let g = "metal.galvanized"
        K.rod(&m, K.arc(V3(0, 0, 0), 1.5, 0, 360, n: 48).map { V3($0.x, 0.85, $0.y) }, r: 0.025, g, sides: 8)
        for i in 0..<6 {
            let a = Float(i) / 6 * 2 * .pi, c = cos(a), s = sin(a)
            K.rod(&m, [V3(c * 1.5, 0.85, s * 1.5), V3(c * 1.45, 0.4, s * 1.45), V3(c * 1.7, 0.0, s * 1.7)], r: 0.022, g, sides: 8)
        }
        m.add(Prim.cylinder(radius: 1.28, height: 0.004, bevel: 0.001, segments: 40, material: "fabric.nylon"), Xform(translation: V3(0, 0.82, 0)))
        m.add(Prim.torus(major: 1.4, minor: 0.05, segments: 48, sides: 8, material: "plastic.black"), Xform(translation: V3(0, 0.88, 0)))
        for i in 0..<72 {
            let a = Float(i) / 72 * 2 * .pi, c = cos(a), s = sin(a)
            K.rod(&m, [V3(c * 1.3, 0.83, s * 1.3), V3(c * 1.47, 0.85, s * 1.47)], r: 0.003, "metal.steel", sides: 4)
        }
        return K.finish(&m)
    }
}
