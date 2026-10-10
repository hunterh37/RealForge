import simd
import Foundation

/// Wall banner on pole: a 0.7 x 1.8 m vertical canvas banner hung from a crossbar between two wall
/// brackets, with a brass finial on each pole end, grommets, a hem weight bar and gentle cloth sag.
public struct WallBannerPole: RealAsset {
    public static let id = "wall-banner-pole"
    public static let summary = "Wall banner, 0.7 x 1.8 m: canvas on a crossbar, wall brackets, brass finials, weight bar."
    public static let tags = ["prop", "architecture", "facade", "sign", "fabric", "metal"]
    public static let budget = 7_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 25, elevation: 6, distance: 3.4)

    public var width: Float = 0.7
    public var height: Float = 1.8
    public var cloth: MaterialKey = "fabric.canvas"
    public var pole: MaterialKey = "metal.wrought-iron"
    public var brass: MaterialKey = "metal.brass-aged"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let W = width, H = height, top = H + 0.1, bz: Float = 0.12
        let barW = W + 0.2
        FA.rod(&m, V3(-barW / 2, top, bz), V3(barW / 2, top, bz), r: 0.012, pole)
        for e: Float in [-1, 1] {
            FA.ball(&m, r: 0.025, at: V3(e * (barW / 2 + 0.012), top, bz), brass)
            let bx = e * (W / 2 - 0.04)
            FA.rod(&m, V3(bx, top, 0.0), V3(bx, top, bz), r: 0.01, pole, sides: 8)
            FA.box(&m, V3(0.07, 0.07, 0.012), V3(bx, top, 0.006), pole, r: 0.002)
            FA.rod(&m, V3(bx, top - 0.1, 0.0), V3(bx, top, bz - 0.01), r: 0.007, pole, sides: 6)
        }
        // Cloth: thin slab with a gentle phase-shifted sag deform.
        var banner = Prim.roundedBox(V3(W, H, 0.006), radius: 0.001, bevelSegments: 1, material: cloth)
        let phase = rng.float(0...6)
        banner.deform { p in
            let f = (p.y + H / 2) / H
            return V3(p.x, p.y, p.z + sin(p.x * 11 + phase) * 0.012 * (1 - f) + p.x * p.x * 0.05)
        }
        m.add(banner, Xform(translation: V3(0, H / 2 - 0.04, bz + 0.02)))
        // Hem pocket and weight bar, stitched top sleeve, grommets.
        FA.rod(&m, V3(-W / 2 + 0.03, 0.02, bz + 0.03), V3(W / 2 - 0.03, 0.02, bz + 0.03), r: 0.012, pole)
        FA.box(&m, V3(W, 0.08, 0.012), V3(0, top - 0.06, bz + 0.016), cloth, r: 0.003)
        for i in 0..<5 { FA.cylZ(&m, r: 0.012, h: 0.006, at: V3(-W / 2 + 0.06 + Float(i) * (W - 0.12) / 4, top - 0.06, bz + 0.024), brass, segments: 10) }
        // Painted emblem: a diamond and band in a contrasting tone.
        FA.box(&m, V3(W * 0.5, W * 0.5, 0.003), V3(0, H * 0.55, bz + 0.026), "fabric.wool", r: 0.002, rot: FA.q(45, FA.Z))
        FA.box(&m, V3(W - 0.1, 0.12, 0.003), V3(0, H * 0.25, bz + 0.026), "fabric.wool", r: 0.002)
        groundAO(&m, height: 0.1, floor: 0.9)
        return LODModel(FC.seatY(m))
    }
}
