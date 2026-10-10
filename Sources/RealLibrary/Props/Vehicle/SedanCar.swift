import simd
import Foundation

/// Mid-size four-door sedan, 4.75 m long, 1.8 m wide, 1.45 m tall: painted body, glass greenhouse, lamps, four wheels.
public struct SedanCar: RealAsset {
    public static let id = "sedan-car"
    public static let summary = "Mid-size sedan, 4.75 m: painted body, tinted glass cabin, head and tail lamps, bumpers, four wheels."
    public static let tags = ["prop", "vehicle", "road", "street", "urban", "metal"]
    public static let budget = 6500
    public static let author = "hunterh37"

    /// Body paint, sRGB hex.
    public var color: UInt32 = 0x6E7B8B
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let p = SK.paint(color)
        SK.side(&m, [V2(-2.35, 0.38), V2(2.3, 0.38), V2(2.38, 0.62), V2(2.3, 0.8), V2(1.1, 0.88), V2(-1.2, 0.9), V2(-2.3, 0.88), V2(-2.38, 0.62)],
                width: 1.8, mat: p, bevel: 0.035)
        SK.side(&m, [V2(-1.2, 0.88), V2(-0.85, 1.4), V2(0.5, 1.42), V2(1.1, 0.88)], width: 1.58, mat: "glass.tinted", bevel: 0.01)
        K.box(&m, V3(0, 1.435, -0.175), V3(1.5, 0.05, 1.4), p, bevel: 0.02)
        for s: Float in [-1, 1] {
            K.box(&m, V3(s * 0.805, 1.15, -0.2), V3(0.06, 0.52, 0.07), "plastic.black", bevel: 0.01)
            K.box(&m, V3(s * 0.95, 0.98, 0.25), V3(0.12, 0.07, 0.16), p, bevel: 0.015)
            K.box(&m, V3(s * 0.72, 0.7, 2.38), V3(0.34, 0.1, 0.04), "emissive.warm", bevel: 0.01)
            K.box(&m, V3(s * 0.72, 0.72, -2.38), V3(0.38, 0.09, 0.04), "emissive.signal-red", bevel: 0.01)
            for z: Float in [1.35, -1.35] { SK.wheel(&m, x: s * 0.8, z: z, r: 0.32, w: 0.22) }
        }
        K.box(&m, V3(0, 0.52, 2.37), V3(1.7, 0.2, 0.1), "plastic.black", bevel: 0.03)
        K.box(&m, V3(0, 0.52, -2.37), V3(1.7, 0.2, 0.1), "plastic.black", bevel: 0.03)
        K.box(&m, V3(0, 0.66, 2.395), V3(0.9, 0.14, 0.02), "plastic.black", bevel: 0.006)
        K.box(&m, V3(0, 0.6, -2.43), V3(0.52, 0.12, 0.015), "plastic.white", bevel: 0.004)
        return K.finish(&m, ao: 0.25)
    }
}
