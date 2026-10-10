import simd
import Foundation

/// Sidewalk newsstand kiosk, 2.2 m wide, 1.6 m deep and 2.5 m tall: green steel box, service window with counter, magazine racks, awning.
public struct Newsstand: RealAsset {
    public static let id = "newsstand"
    public static let summary = "Sidewalk newsstand kiosk, 2.2 x 1.6 m: green steel cabinet, glass service window, counter, stocked magazine racks, awning."
    public static let tags = ["prop", "city", "street", "urban", "metal"]
    public static let budget = 6500
    public static let author = "hunterh37"

    /// Cabinet paint, sRGB hex.
    public var color: UInt32 = 0x2E5A44
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let p = SK.paint(color)
        K.box(&m, V3(0, 0.06, 0), V3(2.2, 0.12, 1.6), "concrete.rough", bevel: 0.01)
        K.box(&m, V3(0, 0.8, -0.05), V3(2.1, 1.35, 1.4), p, bevel: 0.015)
        K.box(&m, V3(0, 1.85, -0.05), V3(2.1, 0.7, 1.4), p, bevel: 0.015)
        K.box(&m, V3(0, 1.45, 0.66), V3(1.8, 0.7, 0.02), "glass.clear", bevel: 0.004)
        K.box(&m, V3(0, 1.1, 0.72), V3(1.9, 0.06, 0.3), "wood.weathered", bevel: 0.006)
        K.box(&m, V3(0, 2.25, -0.05), V3(2.2, 0.08, 1.5), p, bevel: 0.015)
        K.box(&m, V3(0, 1.82, 0.7), V3(1.9, 0.22, 0.02), "emissive.panel", bevel: 0.004)
        SK.sloped(&m, from: V2(0.62, 2.1), to: V2(1.2, 1.9), width: 2.1, thick: 0.03, mat: "fabric.canvas")
        for s: Float in [-1, 1] {
            K.box(&m, V3(s * 1.12, 0.8, 0.0), V3(0.04, 1.35, 1.0), "plastic.black", bevel: 0.006)
            var y: Float = 0.45
            while y < 1.15 {
                for c in 0..<5 {
                    let tint = rng.pick([0xC0392B, 0x2874A6, 0xD4AC0D, 0x1E8449, 0xF2F2F2, 0x8E44AD] as [UInt32])
                    K.box(&m, V3(s * 1.14, y, -0.35 + Float(c) * 0.17), V3(0.012, 0.17, 0.13), "plastic.matte:" + String(format: "%06X", tint), bevel: 0.002)
                }
                y += 0.23
            }
        }
        return K.finish(&m, ao: 0.15)
    }
}
