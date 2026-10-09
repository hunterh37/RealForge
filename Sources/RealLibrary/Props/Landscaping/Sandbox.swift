import simd
import Foundation

public struct Sandbox: RealAsset {
    public static let id = "sandbox"
    public static let summary = "Cedar sandbox, 1.2 m square: four corner-seated boards, bench ledge and sand fill with a toy bucket."
    public static let tags = ["prop", "landscaping", "outdoor", "playground", "wood"]
    public static let budget = 7000
    public static let author = "realityhd"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let w = "wood.lumber-cedar"
        for s: Float in [-1, 1] {
            K.beam(&m, V3(-0.6, 0.12, s * 0.59), V3(0.6, 0.12, s * 0.59), 0.24, 0.035, w, up: V3(0, 0, s))
            K.beam(&m, V3(s * 0.59, 0.12, -0.6), V3(s * 0.59, 0.12, 0.6), 0.24, 0.035, w, up: V3(s, 0, 0))
            K.box(&m, V3(s * 0.5, 0.26, s * 0.5), V3(0.1, 0.04, 0.1), w)
        }
        let sand = Prim.terrain(size: V2(1.13, 1.13), segments: 24, material: "wood.sawdust") { p in 0.07 + 0.01 * sin(p.x * 9) * cos(p.y * 7) }
        m.add(sand, Xform(translation: V3(0, 0.0, 0)))
        m.add(Prim.cylinder(radius: 0.06, height: 0.1, bevel: 0.004, segments: 18, material: "plastic.yellow"), Xform(translation: V3(0.25, 0.08, 0.2)))
        return K.finish(&m)
    }
}
