import simd
import Foundation

/// Window air conditioner: off-white plastic cabinet, louvered front grille, control strip with knob
/// and display, accordion side panels and an angle-iron support bracket below. Yellowed at the vents.
public struct WindowAcUnit: RealAsset {
    public static let id = "window-ac-unit"
    public static let summary = "Window air conditioner, 0.6 m: plastic cabinet, louvered grille, control strip, side fins and support bracket."
    public static let tags = ["prop", "architecture", "facade", "window", "plastic", "metal", "urban"]
    public static let budget = 10_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 35, elevation: 12, distance: 1.4)

    public var width: Float = 0.56
    public var height: Float = 0.37
    public var depth: Float = 0.4
    public var shell: MaterialKey = "plastic.matte:D6D3CA"
    public var grille: MaterialKey = "plastic.matte:BDBAB0"
    public var steel: MaterialKey = "metal.galvanized"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let W = width, H = height, D = depth, y0: Float = 0.1
        FA.box(&m, V3(W, H, D), V3(0, y0 + H / 2, D / 2), shell, r: 0.012)
        FA.box(&m, V3(W + 0.01, 0.025, 0.05), V3(0, y0 + H - 0.0125, D - 0.025), shell, r: 0.006)
        // Louvered grille.
        for i in 0..<9 {
            FA.box(&m, V3(W - 0.1, 0.012, 0.02), V3(0, y0 + 0.06 + Float(i) * 0.024, D + 0.004), grille, r: 0.002, rot: FA.q(-22, FA.X))
        }
        FA.box(&m, V3(W - 0.08, H - 0.14, 0.004), V3(0, y0 + 0.17, D - 0.001), "plastic.black", r: 0.001)
        // Control strip.
        FA.box(&m, V3(W - 0.06, 0.055, 0.012), V3(0, y0 + H - 0.05, D + 0.003), grille, r: 0.004)
        FA.box(&m, V3(0.07, 0.022, 0.004), V3(-0.14, y0 + H - 0.05, D + 0.011), "emissive.led-red", r: 0.001)
        FA.cylZ(&m, r: 0.016, h: 0.014, at: V3(0.12, y0 + H - 0.05, D + 0.009), "plastic.black", bevel: 0.003, segments: 16)
        for i in 0..<3 { FA.cylZ(&m, r: 0.006, h: 0.006, at: V3(0.02 + Float(i) * 0.03, y0 + H - 0.05, D + 0.009), "plastic.white", bevel: 0.001, segments: 10) }
        // Accordion side panels.
        for e: Float in [-1, 1] { for i in 0..<7 {
            FA.box(&m, V3(0.05, H - 0.06, 0.004), V3(e * (W / 2 + 0.018), y0 + H / 2, 0.05 + Float(i) * 0.05), "plastic.matte:E0DDD4", r: 0.001, rot: FA.q(e * (i % 2 == 0 ? 50 : -50), FA.Y))
        }}
        // Support bracket and diagonal braces.
        FA.box(&m, V3(W + 0.1, 0.012, D * 0.7), V3(0, y0 - 0.006, D * 0.35), steel, r: 0.002)
        for x in [-W * 0.35, W * 0.35] { FA.rod(&m, V3(x, 0.01, 0.012), V3(x, y0 - 0.01, D * 0.65), r: 0.007, steel, sides: 8) }
        groundAO(&m, height: 0.1, floor: 0.8)
        return LODModel(FA.centerZ(m))
    }
}
