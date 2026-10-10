import simd
import Foundation

/// Cargo delivery van, 5.5 m long, 2.0 m wide, 2.5 m tall: boxy white body, slanted windshield, side stripe, rear lamps.
public struct DeliveryVan: RealAsset {
    public static let id = "delivery-van"
    public static let summary = "Cargo delivery van, 5.5 m: tall white body, slanted windshield, side stripe, tinted door glass, four wheels."
    public static let tags = ["prop", "vehicle", "road", "street", "urban", "metal"]
    public static let budget = 6900
    public static let author = "hunterh37"

    /// Body paint, sRGB hex.
    public var color: UInt32 = 0xE8E8E4
    /// Side stripe paint, sRGB hex.
    public var stripe: UInt32 = 0x1F5FA8
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let p = SK.paint(color)
        SK.side(&m, [V2(-2.75, 0.45), V2(2.7, 0.45), V2(2.76, 0.85), V2(2.3, 1.05), V2(1.9, 1.85), V2(1.65, 2.45), V2(-2.72, 2.5), V2(-2.78, 2.4)],
                width: 2.0, mat: p, bevel: 0.04)
        SK.sloped(&m, from: V2(2.0, 1.7), to: V2(1.7, 2.3), width: 1.75, thick: 0.03, mat: "glass.tinted")
        for s: Float in [-1, 1] {
            K.box(&m, V3(s * 1.0, 1.9, 1.35), V3(0.03, 0.55, 0.85), "glass.tinted", bevel: 0.006)
            K.box(&m, V3(s * 1.0, 1.0, 0.0), V3(0.025, 0.14, 4.6), SK.paint(stripe), bevel: 0.004)
            K.box(&m, V3(s * 1.0, 1.35, -0.6), V3(0.02, 1.9, 0.02), "plastic.black", bevel: 0.004)
            K.box(&m, V3(s * 0.7, 0.78, 2.76), V3(0.3, 0.12, 0.04), "emissive.warm", bevel: 0.01)
            K.box(&m, V3(s * 0.8, 0.9, -2.8), V3(0.14, 0.4, 0.04), "emissive.signal-red", bevel: 0.01)
            K.box(&m, V3(s * 1.07, 1.75, 1.7), V3(0.1, 0.22, 0.08), "plastic.black", bevel: 0.015)
            for z: Float in [1.75, -1.55] { SK.wheel(&m, x: s * 0.88, z: z, r: 0.36, w: 0.24) }
        }
        K.box(&m, V3(0, 0.6, 2.76), V3(1.9, 0.24, 0.12), "plastic.black", bevel: 0.03)
        K.box(&m, V3(0, 0.55, -2.82), V3(1.9, 0.2, 0.12), "plastic.black", bevel: 0.03)
        K.box(&m, V3(0, 1.45, -2.8), V3(0.03, 1.5, 0.02), "plastic.black", bevel: 0.004)
        return K.finish(&m, ao: 0.3)
    }
}
