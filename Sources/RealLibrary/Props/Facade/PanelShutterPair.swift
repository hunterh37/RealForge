import simd
import Foundation

/// Panel shutter pair: two painted wood leaves (stiles, top, mid and bottom rails, two raised panels per
/// leaf) on iron strap hinges with pintles and two holdbacks. Shown closed against the wall plane.
public struct PanelShutterPair: RealAsset {
    public static let id = "panel-shutter-pair"
    public static let summary = "Raised-panel shutter pair, 1.5 m: painted stiles and rails, two raised panels per leaf, strap hinges and holdbacks."
    public static let tags = ["prop", "architecture", "facade", "trim", "wood", "metal"]
    public static let budget = 8_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 28, elevation: 6, distance: 1.2)

    /// Width of one leaf, height and thickness (m).
    public var leafWidth: Float = 0.5
    public var height: Float = 1.5
    public var thickness: Float = 0.035
    /// Gap between the leaves (m).
    public var gap: Float = 0.006
    public var paint: MaterialKey = "wood.painted-shaker-worn:3C4F63"
    public var hardware: MaterialKey = "metal.cast-iron"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let W = leafWidth, H = height, t = thickness
        let stile: Float = 0.065, rail: Float = 0.09, botRail: Float = 0.13
        let midY = H * 0.5
        for side: Float in [-1, 1] {
            let cx = side * (W / 2 + gap / 2)
            let z0: Float = 0.003
            for e: Float in [-1, 1] {
                FA.box(&m, V3(stile, H, t), V3(cx + e * (W / 2 - stile / 2), H / 2, z0 + t / 2), paint)
            }
            let iw = W - 2 * stile
            for (y, h) in [(H - rail / 2, rail), (midY, rail), (botRail / 2, botRail)] {
                FA.box(&m, V3(iw + 0.004, h, t * 0.96), V3(cx, y, z0 + t / 2), paint)
            }
            for (y0, y1) in [(botRail, midY - rail / 2), (midY + rail / 2, H - rail)] {
                let h = y1 - y0, y = (y0 + y1) / 2
                FA.box(&m, V3(iw, h, 0.010), V3(cx, y, z0 + 0.008), paint, r: 0.002)
                FA.box(&m, V3(iw - 0.06, h - 0.06, 0.016), V3(cx, y, z0 + 0.020), paint, r: 0.006)
            }
            // Strap hinges and pintles on the outer edge.
            let ex = cx + side * (W / 2)
            for y in [0.22, H - 0.22] {
                FA.box(&m, V3(0.24, 0.032, 0.006), V3(cx + side * (W / 2 - 0.12), y, z0 + t + 0.003), hardware, r: 0.0015)
                FA.cylZ(&m, r: 0.009, h: 0.05, at: V3(ex + side * 0.012, y, z0 - 0.002), hardware, bevel: 0.001, segments: 10)
            }
            _ = rng.float()
        }
        groundAO(&m, height: 0.12, floor: 0.7)
        return LODModel(FA.centerZ(m))
    }
}
