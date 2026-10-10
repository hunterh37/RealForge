import simd
import Foundation

/// Roll-down security shutter: galvanized interlocking slats between two guide rails, a rolled-up
/// housing across the top and a bottom bar with a keyed lock and pull ring. Slats carry a faint dent
/// and one is slightly proud, as on a shop front in service.
public struct RollDownShutter: RealAsset {
    public static let id = "roll-down-shutter"
    public static let summary = "Roll-down security shutter, 1.8 m: interlocking steel slats, top housing, side guide rails, bottom bar with lock."
    public static let tags = ["prop", "architecture", "facade", "door", "window", "metal", "urban"]
    public static let budget = 10_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 28, elevation: 8, distance: 1.5)

    /// Opening width and drop height (m).
    public var width: Float = 1.8
    public var height: Float = 1.5
    /// Slat pitch (m).
    public var pitch: Float = 0.055
    public var slat: MaterialKey = "metal.galvanized-aged"
    public var housing: MaterialKey = "metal.painted:5B6168"
    public var guide: MaterialKey = "metal.painted:4A4F55"
    public var steel: MaterialKey = "metal.steel"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let W = width, H = height
        let hh: Float = 0.22
        // Housing with a rolled-curtain bulge.
        FA.box(&m, V3(W + 0.12, hh, 0.24), V3(0, H - hh / 2, 0.13), housing, r: 0.012)
        FA.box(&m, V3(W + 0.14, 0.02, 0.26), V3(0, H - hh - 0.005, 0.13), housing, r: 0.004)
        for e: Float in [-1, 1] {
            FA.box(&m, V3(0.07, H - hh, 0.07), V3(e * (W / 2 + 0.035), (H - hh) / 2, 0.035), guide, r: 0.004)
            FA.box(&m, V3(0.02, H - hh, 0.04), V3(e * (W / 2 - 0.005), (H - hh) / 2, 0.075), guide, r: 0.002)
        }
        let bottomBar: Float = 0.06
        let y0 = bottomBar, y1 = H - hh
        let n = max(2, Int(((y1 - y0) / pitch).rounded()))
        let p = (y1 - y0) / Float(n)
        for i in 0..<n {
            let proud: Float = rng.chance(0.06) ? 0.002 : 0
            let dent = rng.chance(0.1) ? rng.float(-0.0015...0.0015) : 0
            FA.box(&m, V3(W - 0.01, p * 0.94, 0.012), V3(0, y0 + p * (Float(i) + 0.5), 0.05 + proud + dent), slat, r: 0.0035)
        }
        FA.box(&m, V3(W + 0.01, bottomBar, 0.05), V3(0, bottomBar / 2, 0.055), housing, r: 0.006)
        FA.cylZ(&m, r: 0.016, h: 0.03, at: V3(0.3, bottomBar / 2, 0.08), steel, bevel: 0.002, segments: 14)
        FA.cylZ(&m, r: 0.004, h: 0.032, at: V3(0.3, bottomBar / 2, 0.08), "metal.cast-iron", bevel: 0.001, segments: 8)
        m.add(Prim.torus(major: 0.022, minor: 0.004, segments: 16, sides: 6, material: steel),
              Xform(translation: V3(-0.3, bottomBar / 2, 0.085), rotation: FA.q(90, FA.X)))
        groundAO(&m, height: 0.15, floor: 0.7)
        return LODModel(FA.centerZ(m))
    }
}
