import simd
import Foundation

/// Video entry intercom: brushed stainless faceplate in a dark bezel with a camera dome, perforated
/// speaker, four call buttons with lit name strips and a green status LED.
public struct EntryIntercom: RealAsset {
    public static let id = "entry-intercom"
    public static let summary = "Video entry intercom, 0.12 m x 0.36 m: stainless plate, camera lens, speaker, four buttons and status LED."
    public static let tags = ["prop", "architecture", "facade", "door", "electronics", "metal", "urban"]
    public static let budget = 6_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 25, elevation: 8, distance: 0.6)

    public var plate: MaterialKey = "metal.stainless"
    public var bezel: MaterialKey = "plastic.black"
    public var strip: MaterialKey = "emissive.warm"
    public var led: MaterialKey = "emissive.led-green"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let w: Float = 0.12, h: Float = 0.36
        FA.box(&m, V3(w + 0.02, h + 0.02, 0.02), V3(0, h / 2 + 0.01, 0.01), bezel, r: 0.006)
        FA.box(&m, V3(w, h, 0.012), V3(0, h / 2 + 0.01, 0.026), plate, r: 0.003)
        // Camera dome.
        let cy = h - 0.04
        FA.cylZ(&m, r: 0.022, h: 0.01, at: V3(0, cy, 0.032), bezel, bevel: 0.002, segments: 20)
        m.add(Prim.superellipsoid(V3(0.032, 0.032, 0.02), exponent: 2, subdivisions: 8, material: "glass.led-lens"), Xform(translation: V3(0, cy, 0.04)))
        FA.ball(&m, r: 0.003, at: V3(w / 2 - 0.014, cy + 0.02, 0.034), led)
        // Speaker grille: three rows of dimples.
        for r in 0..<3 { for c in 0..<6 {
            let x = (Float(c) - 2.5) * 0.013, y = h - 0.11 - Float(r) * 0.013
            FA.cylZ(&m, r: 0.0033, h: 0.002, at: V3(x, y, 0.0315), bezel, bevel: 0.0005, segments: 6)
        }}
        // Call buttons with name strips.
        for i in 0..<4 {
            let y = h - 0.19 - Float(i) * 0.05
            FA.box(&m, V3(0.092, 0.036, 0.008), V3(0, y, 0.034), bezel, r: 0.004)
            FA.box(&m, V3(0.07, 0.016, 0.003), V3(-0.004, y, 0.0395), strip, r: 0.001)
            FA.cylZ(&m, r: 0.0065, h: 0.003, at: V3(0.033, y, 0.038), plate, bevel: 0.001, segments: 14)
        }
        for sx: Float in [-1, 1] { hexBolt(&m, at: V3(sx * (w / 2 - 0.006), 0.02, 0.032), normal: FA.Z, size: 0.006, material: "metal.steel") }
        return LODModel(FA.centerZ(m))
    }
}
