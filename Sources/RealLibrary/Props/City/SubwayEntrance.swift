import simd
import Foundation

/// Subway station stair entrance, 3.0 m wide and 5.0 m long: guard railings, dark stairwell opening, glass canopy, lit globe lamps.
public struct SubwayEntrance: RealAsset {
    public static let id = "subway-entrance"
    public static let summary = "Subway station stair entrance, 3 x 5 m: green steel railings, stairwell opening, glass canopy, two lit globe lamps."
    public static let tags = ["prop", "city", "urban", "street", "rail", "metal"]
    public static let budget = 2100
    public static let author = "hunterh37"

    /// Railing paint, sRGB hex.
    public var color: UInt32 = 0x1B5E3A
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let p = SK.paint(color), hw: Float = 1.5, len: Float = 5.0
        K.box(&m, V3(0, 0.01, 0), V3(2.4, 0.02, len - 0.4), "plastic.black", bevel: 0.004)
        for s: Float in [-1, 1] {
            K.box(&m, V3(s * (hw - 0.05), 0.06, 0), V3(0.3, 0.12, len), "concrete.sidewalk", bevel: 0.01)
            var z = -len / 2 + 0.1
            while z <= len / 2 {
                K.rod(&m, [V3(s * hw, 0.1, z), V3(s * hw, 1.05, z)], r: 0.022, p, sides: 8)
                z += 0.5
            }
            K.rod(&m, [V3(s * hw, 1.07, -len / 2), V3(s * hw, 1.07, len / 2)], r: 0.032, p, sides: 10)
            K.rod(&m, [V3(s * hw, 0.5, -len / 2), V3(s * hw, 0.5, len / 2)], r: 0.016, p, sides: 8)
        }
        for z: Float in [-len / 2, len / 2] {
            K.rod(&m, [V3(-hw, 1.07, z), V3(hw, 1.07, z)], r: 0.032, p, sides: 10)
        }
        for s: Float in [-1, 1] {
            for z: Float in [-1.2, 1.2] { K.rod(&m, [V3(s * 1.2, 0.1, z), V3(s * 1.2, 2.6, z)], r: 0.05, p, sides: 10) }
            K.rod(&m, [V3(s * 1.2, 2.6, -1.2), V3(s * 1.2, 2.6, 1.2)], r: 0.04, p, sides: 10)
        }
        K.box(&m, V3(0, 2.66, 0), V3(2.6, 0.05, 2.7), "glass.tinted", bevel: 0.008)
        K.box(&m, V3(0, 2.72, 0), V3(0.06, 0.04, 2.7), p, bevel: 0.004)
        for z: Float in [-len / 2, len / 2] {
            K.rod(&m, [V3(hw, 0.1, z), V3(hw, 1.9, z)], r: 0.04, p, sides: 10)
            K.rod(&m, [V3(hw, 1.9, z), V3(hw - 0.2, 2.1, z)], r: 0.025, p, sides: 8)
            m.add(Prim.cubeSphere(subdivisions: 3, material: "emissive.signal-green") { d in d * 0.17 }, Xform(translation: V3(hw - 0.2, 2.25, z)))
        }
        return K.finish(&m, ao: 0.1)
    }
}
