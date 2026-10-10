import simd
import Foundation

/// Full-size pickup, 5.3 m long, 2.0 m wide, 1.9 m tall: crew cab, open bed with tailgate, tinted glass.
public struct PickupTruck: RealAsset {
    public static let id = "pickup-truck"
    public static let summary = "Full-size pickup truck, 5.3 m: cab with slanted windshield, open cargo bed with tailgate, four wheels."
    public static let tags = ["prop", "vehicle", "road", "street", "urban", "construction", "metal"]
    public static let budget = 6700
    public static let author = "hunterh37"

    /// Body paint, sRGB hex.
    public var color: UInt32 = 0x9B2D20
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let p = SK.paint(color)
        SK.side(&m, [V2(-0.2, 0.5), V2(2.6, 0.5), V2(2.66, 0.95), V2(2.25, 1.15), V2(1.5, 1.2), V2(1.05, 1.85), V2(-0.2, 1.88)], width: 2.0, mat: p, bevel: 0.04)
        SK.sloped(&m, from: V2(1.45, 1.22), to: V2(1.08, 1.8), width: 1.75, thick: 0.03, mat: "glass.tinted")
        K.box(&m, V3(0, 0.88, -1.45), V3(2.0, 0.08, 2.5), "metal.painted:2A2B2D", bevel: 0.01)
        for s: Float in [-1, 1] {
            K.box(&m, V3(s * 1.0, 1.52, 0.4), V3(0.03, 0.5, 1.15), "glass.tinted", bevel: 0.006)
            K.box(&m, V3(s * 0.96, 1.18, -1.45), V3(0.1, 0.55, 2.5), p, bevel: 0.02)
            K.box(&m, V3(s * 0.7, 0.9, 2.66), V3(0.32, 0.14, 0.04), "emissive.warm", bevel: 0.01)
            K.box(&m, V3(s * 0.8, 1.2, -2.64), V3(0.1, 0.22, 0.04), "emissive.signal-red", bevel: 0.01)
            for z: Float in [1.75, -1.5] { SK.wheel(&m, x: s * 0.88, z: z, r: 0.38, w: 0.26) }
        }
        K.box(&m, V3(0, 1.18, -0.3), V3(1.82, 0.55, 0.08), p, bevel: 0.02)
        K.box(&m, V3(0, 1.1, -2.64), V3(1.82, 0.5, 0.07), p, bevel: 0.02)
        K.box(&m, V3(0, 0.62, 2.66), V3(2.0, 0.22, 0.12), "metal.chrome", bevel: 0.03)
        K.box(&m, V3(0, 0.58, -2.68), V3(2.0, 0.2, 0.12), "metal.chrome", bevel: 0.03)
        K.box(&m, V3(0, 0.82, 2.68), V3(0.95, 0.2, 0.02), "plastic.black", bevel: 0.006)
        return K.finish(&m, ao: 0.3)
    }
}
