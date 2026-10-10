import simd
import Foundation

/// Solar parking pay-and-display station, 1.65 m tall: blue steel cabinet, lit screen, keypad, card and coin slots, solar roof, "P" topper.
public struct PayStation: RealAsset {
    public static let id = "pay-station"
    public static let summary = "Parking pay station, 1.65 m: blue steel cabinet, lit display, keypad, card slot, ticket tray, solar roof, P topper."
    public static let tags = ["prop", "city", "street", "urban", "road", "electronics", "metal"]
    public static let budget = 3100
    public static let author = "hunterh37"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let blue = SK.paint(0x1F4E8C)
        K.box(&m, V3(0, 0.03, 0), V3(0.44, 0.06, 0.34), "concrete.rough", bevel: 0.006)
        K.box(&m, V3(0, 0.76, 0), V3(0.34, 1.4, 0.26), blue, bevel: 0.02)
        K.box(&m, V3(0, 1.1, 0.131), V3(0.24, 0.16, 0.006), "emissive.panel", bevel: 0.002)
        K.box(&m, V3(0, 0.88, 0.131), V3(0.18, 0.14, 0.008), "plastic.black", bevel: 0.002)
        for r in 0..<4 { for c in 0..<3 {
            K.box(&m, V3(-0.05 + Float(c) * 0.05, 0.93 - Float(r) * 0.035, 0.137), V3(0.035, 0.024, 0.008), "plastic.gloss", bevel: 0.003)
        } }
        K.box(&m, V3(0, 0.7, 0.135), V3(0.2, 0.012, 0.012), "plastic.black", bevel: 0.002)
        K.box(&m, V3(0, 0.55, 0.12), V3(0.22, 0.09, 0.05), "plastic.black", bevel: 0.01)
        K.box(&m, V3(0, 1.0, 0.131), V3(0.07, 0.016, 0.008), "metal.steel", bevel: 0.002)
        SK.sloped(&m, from: V2(-0.17, 1.52), to: V2(0.2, 1.57), width: 0.4, thick: 0.025, mat: "plastic.matte:15181C")
        K.box(&m, V3(0, 1.48, 0), V3(0.36, 0.1, 0.28), blue, bevel: 0.02)
        K.rod(&m, [V3(0, 1.5, -0.1), V3(0, 1.72, -0.1)], r: 0.018, "metal.galvanized", sides: 8)
        K.box(&m, V3(0, 1.82, -0.1), V3(0.3, 0.3, 0.02), "sign.white", bevel: 0.006)
        K.box(&m, V3(0.015, 1.82, -0.088), V3(0.1, 0.2, 0.006), "plastic.matte:1F4E8C", bevel: 0.002)
        return K.finish(&m, ao: 0.1)
    }
}
