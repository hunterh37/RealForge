import simd
import Foundation

/// Monstera, 1.0 m: potted plant with 9-13 long petioles carrying broad glossy leaves with a raised midrib.
public struct MonsteraPlant: RealAsset {
    public static let id = "monstera-plant"
    public static let summary = "Monstera, 1.0 m: terracotta pot with 9-13 petioles and broad glossy leaves."
    public static let tags = ["prop", "landscaping", "garden", "plant", "foliage", "outdoor"]
    public static let budget = 12000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 30, elevation: 20)

    public var leaves = 9...13
    public var height: ClosedRange<Float> = 0.45...0.8
    public var leafLength: ClosedRange<Float> = 0.28...0.4
    public var leafColor = "2E6A35"
    public var stemColor = "5E7A3A"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        LODModel(levels: [model(seed: seed, detail: true), model(seed: seed, detail: false)], switchDistances: [6])
    }

    func model(seed: UInt64, detail: Bool) -> Model {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let y = FlowerKit.pot(&m, top: 0.3, foot: 0.22, height: 0.28, detail: detail)
        let lm: MaterialKey = "leaf.plain:" + leafColor, sm: MaterialKey = "plant.stem:" + stemColor
        var st = Surface(material: sm), lf = Surface(material: lm)
        var r = rng.fork(1)
        for i in 0..<r.int(leaves) {
            let a = Float(i) * 2.4 + r.float(-0.3...0.3), rr = 0.05 * sqrt(r.float())
            let pts = PlantKit.arc(from: V3(cos(a) * rr, y, sin(a) * rr), height: r.float(height), yaw: a, lean: r.float(0.15...0.5), bend: r.float(0.2...0.5), count: 5)
            st.append(PlantKit.stem(pts, radius: 0.007, tipRadius: 0.005, sides: detail ? 5 : 3, weight: V2(0, 0.4), phase: Float(i) * 0.5, material: sm))
            let top = pts[pts.count - 1]
            var b = PlantKit.Blade()
            b.root = top; b.yaw = a + r.float(-0.4...0.4); b.length = r.float(leafLength); b.width = b.length * 0.62; b.tipWidth = 0.08
            b.lean = r.float(1.0...1.5); b.curl = r.float(0.6...1.1); b.twist = r.float(-0.3...0.3); b.fold = 0.18; b.belly = 0.55
            b.segments = detail ? 6 : 3; b.u = V2(0, b.width); b.v = V2(0, b.length); b.weight = V2(0.3, 0.8); b.phase = Float(i) * 0.5; b.ao = V2(0.5, 1); b.upNormal = 0.3
            lf.append(PlantKit.blade(b, material: lm))
        }
        m.add(st); m.add(lf)
        PlantKit.finish(&m)
        return ShrubKit.centered(m)
    }
}
