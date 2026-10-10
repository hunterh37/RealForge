import simd
import Foundation

/// Fiddle-leaf fig, 1.6 m: potted single trunk with 14-20 large violin-shaped leaves alternating up its upper two thirds.
public struct FiddleLeafFig: RealAsset {
    public static let id = "fiddle-leaf-fig"
    public static let summary = "Fiddle-leaf fig, 1.6 m: potted trunk with 14-20 large violin-shaped leaves."
    public static let tags = ["prop", "landscaping", "garden", "plant", "foliage", "outdoor"]
    public static let budget = 10000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 30, elevation: 15, distance: 3.5)

    public var leaves = 14...20
    public var trunkHeight: Float = 1.25
    public var leafLength: ClosedRange<Float> = 0.24...0.34
    public var leafColor = "2F5E2A"
    public var trunkColor = "7A6A52"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        LODModel(levels: [model(seed: seed, detail: true), model(seed: seed, detail: false)], switchDistances: [7])
    }

    func model(seed: UInt64, detail: Bool) -> Model {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let y = FlowerKit.pot(&m, top: 0.34, foot: 0.24, height: 0.32, detail: detail)
        let lm: MaterialKey = "leaf.plain:" + leafColor, tm: MaterialKey = "plant.stem:" + trunkColor
        var r = rng.fork(1)
        let pts = PlantKit.arc(from: V3(0, y, 0), height: trunkHeight, yaw: r.float(0...(2 * .pi)), lean: 0.05, bend: 0.12, count: 8)
        var tr = PlantKit.stem(pts, radius: 0.016, tipRadius: 0.007, sides: detail ? 8 : 5, weight: V2(0, 0.3), phase: 0, material: tm)
        var lf = Surface(material: lm)
        let n = r.int(leaves)
        for i in 0..<n {
            let t = 0.3 + 0.7 * Float(i) / Float(n)
            let p = FlowerKit.at(pts, t), size = 1.1 - 0.4 * t
            var b = PlantKit.Blade()
            b.root = p; b.yaw = Float(i) * 2.4 + r.float(-0.25...0.25); b.length = r.float(leafLength) * size; b.width = b.length * 0.4; b.tipWidth = 1.5
            b.lean = r.float(0.9...1.4) - 0.3 * t; b.curl = r.float(0.4...0.9); b.fold = 0.14; b.belly = 1.5
            b.segments = detail ? 6 : 3; b.u = V2(0, b.width); b.v = V2(0, b.length); b.weight = V2(0.2, 0.7); b.phase = Float(i) * 0.4; b.ao = V2(0.5, 1); b.upNormal = 0.3
            lf.append(PlantKit.blade(b, material: lm))
        }
        tr.material = tm
        m.add(tr); m.add(lf)
        PlantKit.finish(&m)
        return ShrubKit.centered(m)
    }
}
