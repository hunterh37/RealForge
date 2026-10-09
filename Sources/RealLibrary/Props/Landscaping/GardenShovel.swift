import simd
import Foundation

public struct GardenShovel: RealAsset {
    public static let id = "garden-shovel"
    public static let summary = "Round-point digging shovel, 1.1 m: steel blade with turned rim, ash shaft and D-grip."
    public static let tags = ["prop", "landscaping", "garden", "outdoor", "tool", "handheld", "metal"]
    public static let budget = 4000
    public static let author = "realityhd"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let st = "metal.steel", ash = "wood.beech-stained"
        K.rod(&m, [V3(0, 0.3, 0), V3(0, 1.0, 0)], r: 0.016, ash, sides: 12)
        K.rod(&m, [V3(-0.1, 1.0, 0), V3(-0.1, 1.08, 0), V3(0.1, 1.08, 0), V3(0.1, 1.0, 0)], r: 0.014, ash, sides: 10)
        K.box(&m, V3(0, 0.3, 0), V3(0.034, 0.1, 0.034), st)
        m.add(Prim.extrude(Shape2D.rounded([V2(-0.1, 0.3), V2(0.1, 0.3), V2(0.1, 0.12), V2(0, 0), V2(-0.1, 0.12)], radius: 0.01), depth: 0.0025, bevel: 0.001, bevelSegments: 1, material: st), Xform(translation: V3(0, 0, 0), rotation: simd_quatf(degrees: 8, axis: V3(1, 0, 0))))
        return K.finish(&m)
    }
}
