import simd
import Foundation

/// Succulent bowl, 0.2 m: shallow terracotta bowl with 5-7 rosettes of thick pointed leaves in two blue-green tints.
public struct SucculentBowl: RealAsset {
    public static let id = "succulent-bowl"
    public static let summary = "Succulent bowl, 0.2 m: shallow terracotta bowl with 5-7 rosettes of thick pointed leaves."
    public static let tags = ["prop", "landscaping", "garden", "plant", "foliage", "outdoor"]
    public static let budget = 12000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 30, elevation: 35, distance: 0.8)

    public var rosettes = 5...7
    public var bowlTop: Float = 0.32
    public var colors = ["7FA88C", "A8B890", "8FB0A8"]
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        LODModel(levels: [model(seed: seed, detail: true), model(seed: seed, detail: false)], switchDistances: [5])
    }

    func model(seed: UInt64, detail: Bool) -> Model {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let y = FlowerKit.pot(&m, top: bowlTop, foot: bowlTop * 0.7, height: 0.1, detail: detail)
        var r = rng.fork(1)
        var surfaces = colors.map { Surface(material: "leaf.agave:" + $0) }
        let n = r.int(rosettes)
        for i in 0..<n {
            let a = Float(i) * 2.4 + r.float(-0.3...0.3), d = i == 0 ? 0 : (bowlTop / 2 - 0.07) * sqrt(Float(i) / Float(n)) + r.float(0...0.02)
            let c = V3(cos(a) * d, y, sin(a) * d), size = r.float(0.7...1.2) * (i == 0 ? 1.25 : 1)
            let k = i % surfaces.count
            for ring in 0..<3 {
                for j in 0..<(8 + ring * 4) {
                    var b = PlantKit.Blade()
                    b.root = c; b.yaw = Float(j) * 2 * .pi / Float(8 + ring * 4) + Float(ring) * 0.5 + r.float(-0.15...0.15)
                    b.length = (0.05 + 0.03 * Float(2 - ring)) * size; b.width = 0.03 * size; b.tipWidth = 0.15
                    b.lean = 0.4 + 0.475 * Float(ring); b.curl = 0.25; b.fold = 0.35; b.belly = 0.5
                    b.segments = detail ? 3 : 2; b.u = V2(0, b.width); b.v = V2(0, b.length); b.weight = V2(0, 0.2); b.ao = V2(0.5, 1)
                    surfaces[k].append(PlantKit.blade(b, material: surfaces[k].material))
                }
            }
        }
        for s in surfaces where !s.isEmpty { m.add(s) }
        PlantKit.finish(&m)
        return ShrubKit.centered(m)
    }
}
