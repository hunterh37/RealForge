import simd
import Foundation

public struct PruningShears: RealAsset {
    public static let id = "pruning-shears"
    public static let summary = "Bypass hand pruners, 0.21 m: red enamel grips, steel blade, anvil hook, spring and lock latch."
    public static let tags = ["prop", "landscaping", "garden", "outdoor", "tool", "handheld", "metal"]
    public static let budget = 3000
    public static let author = "realityhd"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let st = "metal.steel", red = "plastic.orange"
        K.rod(&m, [V3(-0.1, 0.01, 0), V3(-0.02, 0.012, 0.006), V3(0.06, 0.014, 0)], r: 0.007, red, sides: 10)
        K.rod(&m, [V3(-0.1, 0.01, 0.025), V3(-0.02, 0.014, 0.012), V3(0.03, 0.016, 0.006)], r: 0.007, red, sides: 10)
        K.box(&m, V3(0.075, 0.017, 0.004), V3(0.07, 0.006, 0.003), st)
        K.box(&m, V3(0.07, 0.014, 0.012), V3(0.06, 0.006, 0.003), st)
        m.add(Prim.cylinder(radius: 0.005, height: 0.012, bevel: 0.001, segments: 10, material: st), Xform(translation: V3(0.03, 0.008, 0.008)))
        K.rod(&m, K.arc(V3(-0.03, 0.03, 0.01), 0.012, 0, 300, n: 10), r: 0.0012, st, sides: 4)
        return K.finish(&m)
    }
}
