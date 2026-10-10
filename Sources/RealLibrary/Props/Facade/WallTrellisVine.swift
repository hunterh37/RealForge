import simd
import Foundation

/// Wall trellis with climbing vine: a 1.2 x 2.2 m cedar diamond lattice in a mitred frame, stood off
/// the wall on spacer blocks, with a twining stem and clusters of privet-leaf cards climbing it.
public struct WallTrellisVine: RealAsset {
    public static let id = "wall-trellis-vine"
    public static let summary = "Cedar diamond trellis 1.2 x 2.2 m on standoffs, with a twining vine and leaf clusters."
    public static let tags = ["prop", "architecture", "facade", "garden", "wood", "plant"]
    public static let budget = 15_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 25, elevation: 8, distance: 4.4)

    public var width: Float = 1.2
    public var height: Float = 2.2
    public var leafClusters: Int = 34
    public var slat: MaterialKey = "wood.cedar-weathered"
    public var leaf: MaterialKey = "leaf.plain"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let W = width, H = height, so: Float = 0.04
        // Frame.
        FA.box(&m, V3(0.05, H, 0.03), V3(-W / 2 + 0.025, H / 2, so), slat, r: 0.003)
        FA.box(&m, V3(0.05, H, 0.03), V3(W / 2 - 0.025, H / 2, so), slat, r: 0.003)
        FA.box(&m, V3(W, 0.05, 0.03), V3(0, 0.025, so), slat, r: 0.003)
        FA.box(&m, V3(W, 0.05, 0.03), V3(0, H - 0.025, so), slat, r: 0.003)
        // Diamond lattice at 45 degrees, pitch 0.2: two slat layers.
        let pitch: Float = 0.2
        for layer in 0..<2 {
            let sgn: Float = layer == 0 ? 1 : -1
            let n = Int((W + H) / pitch)
            for i in 0..<n {
                let c = Float(i) * pitch - H
                // line y = sgn * x + c + H/2 clipped to the inner window.
                var pts: [V3] = []
                for t in stride(from: -W / 2 + 0.05, through: W / 2 - 0.05, by: 0.05) {
                    let y = sgn * t + c + H / 2
                    if y > 0.05 && y < H - 0.05 { pts.append(V3(t, y, so + (layer == 0 ? 0.012 : -0.012))) }
                }
                if pts.count >= 2 { FA.path(&m, [pts.first!, pts.last!], r: 0.007, slat, sides: 4) }
            }
        }
        // Standoff blocks.
        for (x, y) in [(-W / 2 + 0.03, 0.2), (W / 2 - 0.03, 0.2), (-W / 2 + 0.03, H - 0.2), (W / 2 - 0.03, H - 0.2), (0.0, H / 2)] as [(Float, Float)] {
            FA.box(&m, V3(0.04, 0.04, so - 0.012), V3(x, y, (so - 0.012) / 2), slat, r: 0.003)
        }
        // Twining stem from the base, then leaf clusters along and near the stem.
        var stem: [V3] = []
        for i in 0...24 {
            let t = Float(i) / 24
            stem.append(V3(sin(t * 9 + 0.7) * W * 0.3 + (t - 0.5) * 0.1, 0.05 + t * (H - 0.4), so + 0.026 + sin(t * 17) * 0.012))
        }
        FA.path(&m, stem, r: 0.009, "wood.deadwood", sides: 6)
        for i in 0..<leafClusters {
            let s = stem[min(24, Int(Float(i) / Float(leafClusters) * 25))]
            for _ in 0..<3 {
                let o = V3(rng.float(-0.12...0.12), rng.float(-0.06...0.06), rng.float(0.0...0.05))
                m.add(Prim.superellipsoid(V3(0.09, 0.11, 0.02) * rng.float(0.8...1.3), exponent: 2.5, subdivisions: 3, material: leaf),
                      Xform(translation: s + o, rotation: FA.q(rng.float(0...360), FA.Z) * FA.q(rng.float(-30...30), FA.X)))
            }
        }
        groundAO(&m, height: 0.12, floor: 0.85)
        return LODModel(FC.seatY(m))
    }
}
