import simd
import Foundation

/// Chimney stack with three terracotta pots: a 0.9 x 0.5 m brick shaft with corbelled cap, lead
/// flashing apron and pots of different heights (round, crown and cannon head) with a bird guard.
public struct ChimneyPotCluster: RealAsset {
    public static let id = "chimney-pot-cluster"
    public static let summary = "Chimney stack, 0.9 m: brick shaft, corbelled cap, lead flashing, three terracotta pots."
    public static let tags = ["prop", "architecture", "facade", "roof", "brick", "ceramic"]
    public static let budget = 12_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 35, elevation: 18, distance: 3.6)

    public var width: Float = 0.9
    public var depth: Float = 0.5
    public var shaftHeight: Float = 1.1
    public var brick: MaterialKey = "brick.common"
    public var pot: MaterialKey = "ceramic.terracotta"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let W = width, D = depth, H = shaftHeight
        FA.box(&m, V3(W, H, D), V3(0, H / 2, 0), brick, r: 0.003)
        for (i, ins) in [0.0 as Float, 0.03, 0.06].enumerated() {
            FA.box(&m, V3(W + 0.1 - ins, 0.07, D + 0.1 - ins), V3(0, H + Float(i) * 0.07 + 0.035, 0), brick, r: 0.004)
        }
        FA.box(&m, V3(W + 0.14, 0.04, D + 0.14), V3(0, H + 0.235, 0), "stone.cast-stone", r: 0.004)
        // Lead flashing collar at the foot.
        FA.box(&m, V3(W + 0.1, 0.12, D + 0.1), V3(0, 0.06, 0), "metal.tinned-copper", r: 0.004)
        let top = H + 0.255
        let heights: [Float] = [0.5, 0.38, 0.45]
        for k in 0..<3 {
            let x = (Float(k) - 1) * 0.28
            let h = heights[k] + rng.float(-0.02...0.02)
            let r: Float = k == 1 ? 0.085 : 0.075
            let prof: [V2] = [V2(0.0, 0.0), V2(r + 0.02, 0.0), V2(r + 0.02, 0.05), V2(r, 0.06), V2(r * 0.88, h * 0.45), V2(r * 0.8, h * 0.8),
                              V2(r * 0.95, h * 0.9), V2(r + 0.03, h * 0.94), V2(r + 0.03, h), V2(r * 0.7, h), V2(r * 0.7, h - 0.01)]
            m.add(Prim.lathe(prof, segments: 20, material: pot), Xform(translation: V3(x, top, 0)))
            m.add(Prim.torus(major: r + 0.03, minor: 0.008, segments: 18, sides: 5, material: pot), Xform(translation: V3(x, top + h * 0.9, 0)))
            // Wire bird guard dome.
            if k == 0 { m.add(Prim.lathe([V2(0.07, 0), V2(0.07, 0.04), V2(0.04, 0.09), V2(0.0, 0.1)], segments: 10, material: "metal.galvanized"), Xform(translation: V3(x, top + h, 0))) }
        }
        groundAO(&m, height: 0.15, floor: 0.8)
        return LODModel(FC.place(m))
    }
}
