import simd
import Foundation

/// Pair of 0.6 x 1.5 m raised-panel exterior shutters with stiles, rails, inset panels and strap hinges.
public struct PanelShutterPair: RealAsset {
    public static let id = "panel-shutter-pair"
    public static let summary = "Pair of 0.6 x 1.5 m raised-panel exterior shutters with stiles, rails, inset panels and strap hinges."
    public static let tags = ["prop", "facade", "window", "wood"]
    public static let budget = 3500
    public static let author = "hunterh37"

    /// Primary material key.
    public var material: String = "wood.painted-exterior:2F4A3A"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let material = self.material
        let h: Float = 1.5, lw: Float = 0.58, d: Float = 0.04
        for s: Float in [-1, 1] {
            let cx = s * (lw / 2 + 0.01)
            for sx: Float in [-1, 1] { K.box(&m, V3(cx + sx * (lw / 2 - 0.035), h / 2, 0), V3(0.07, h, d), material, bevel: 0.004) }
            for y: Float in [0.035, h / 2, h - 0.035] { K.box(&m, V3(cx, y, 0), V3(lw - 0.14, y == h / 2 ? 0.06 : 0.07, d), material, bevel: 0.004) }
            for (y0, y1) in [(0.07 as Float, h / 2 - 0.03), (h / 2 + 0.03, h - 0.07)] {
                K.box(&m, V3(cx, (y0 + y1) / 2, 0.006), V3(lw - 0.16, y1 - y0, d - 0.012), material, bevel: 0.006)
            }
            for y: Float in [0.25, h - 0.25] {
                K.box(&m, V3(cx + s * 0.1, y, d / 2 + 0.002), V3(lw * 0.7, 0.03, 0.004), "metal.painted:1A1A1A", bevel: 0.001)
                cy(&m, 0.012, 0.03, V3(cx - s * (lw / 2 + 0.005), y - 0.015, d / 2), "metal.painted:1A1A1A", bevel: 0.002, seg: 12)
            }
        }
        return K.finish(&m, ao: 0.05)
    }
}
