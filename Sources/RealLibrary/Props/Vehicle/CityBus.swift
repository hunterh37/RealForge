import simd
import Foundation

/// Low-floor city transit bus, 12 m long, 2.55 m wide, 3.2 m tall: window band, two doors, destination sign, roof pod.
public struct CityBus: RealAsset {
    public static let id = "city-bus"
    public static let summary = "Low-floor city transit bus, 12 m: livery stripe, window band, two doors, lit destination sign, roof AC pod."
    public static let tags = ["prop", "vehicle", "road", "street", "urban", "metal"]
    public static let budget = 7000
    public static let author = "hunterh37"

    /// Livery paint, sRGB hex.
    public var color: UInt32 = 0xF2F2EE
    /// Livery stripe paint, sRGB hex.
    public var stripe: UInt32 = 0x1E7A4C
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        SK.side(&m, [V2(-6, 0.45), V2(5.9, 0.45), V2(6.0, 0.9), V2(6.0, 3.0), V2(5.9, 3.2), V2(-5.9, 3.2), V2(-6, 3.0), V2(-6, 0.9)],
                width: 2.55, mat: SK.paint(color), bevel: 0.08)
        K.box(&m, V3(0, 2.1, -0.2), V3(2.57, 0.9, 10.6), "glass.tinted", bevel: 0.01)
        K.box(&m, V3(0, 2.3, 6.0), V3(2.3, 1.0, 0.04), "glass.tinted", bevel: 0.01)
        K.box(&m, V3(0, 3.0, 6.01), V3(1.7, 0.18, 0.03), "emissive.warm", bevel: 0.006)
        K.box(&m, V3(0, 1.0, 0.0), V3(2.57, 0.28, 11.8), SK.paint(stripe), bevel: 0.01)
        K.box(&m, V3(0, 3.35, -2.0), V3(1.5, 0.28, 3.2), "plastic.matte:B8BCC0", bevel: 0.05)
        for s: Float in [-1, 1] {
            for z: Float in [3.6, -0.4] { K.box(&m, V3(s * 1.28, 1.6, z), V3(0.03, 2.2, 1.15), "glass.tinted", bevel: 0.008) }
            K.box(&m, V3(s * 1.0, 0.8, 5.99), V3(0.3, 0.14, 0.04), "emissive.warm", bevel: 0.01)
            K.box(&m, V3(s * 1.0, 0.9, -6.0), V3(0.2, 0.5, 0.04), "emissive.signal-red", bevel: 0.01)
            K.box(&m, V3(s * 1.35, 2.5, 5.4), V3(0.1, 0.35, 0.1), "plastic.black", bevel: 0.02)
            SK.wheel(&m, x: s * 1.0, z: 4.2, r: 0.5, w: 0.3)
            SK.wheel(&m, x: s * 1.0, z: -3.6, r: 0.5, w: 0.3)
        }
        K.box(&m, V3(0, 0.6, 6.0), V3(2.4, 0.3, 0.12), "plastic.black", bevel: 0.04)
        K.box(&m, V3(0, 0.6, -6.0), V3(2.4, 0.3, 0.12), "plastic.black", bevel: 0.04)
        return K.finish(&m, ao: 0.4)
    }
}
