import simd
import Foundation

/// Bamboo clump, 3.5 m: 12-20 green culms leaning from a tight base, leaf clusters on the upper half.
public struct BambooClump: RealAsset {
    public static let id = "bamboo-clump"
    public static let summary = "Bamboo clump, 3.5 m: 12-20 green culms with lanceolate leaf clusters on the upper half."
    public static let tags = ["prop", "landscaping", "garden", "plant", "foliage", "outdoor"]
    public static let budget = 14000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 30, elevation: 10, distance: 7)

    public var culms = 12...20
    public var height: ClosedRange<Float> = 2.6...3.8
    public var spread: Float = 0.3
    public var culmColor = "9AA84E"
    public var leafColor = "5E8A34"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        LODModel(levels: [model(seed: seed, detail: true), model(seed: seed, detail: false)], switchDistances: [12])
    }

    func model(seed: UInt64, detail: Bool) -> Model {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let cm: MaterialKey = "plant.stem:" + culmColor, lm: MaterialKey = "leaf.plain:" + leafColor
        var st = Surface(material: cm), lf = Surface(material: lm)
        var r = rng.fork(1)
        for i in 0..<r.int(culms) {
            let a = r.float(0...(2 * .pi)), rr = spread * sqrt(r.float())
            let pts = PlantKit.arc(from: V3(cos(a) * rr, 0, sin(a) * rr), height: r.float(height), yaw: a, lean: r.float(0.03...0.14), bend: r.float(0.1...0.35), count: 8)
            st.append(PlantKit.stem(pts, radius: 0.016, tipRadius: 0.006, sides: detail ? 7 : 4, weight: V2(0, 0.6), phase: Float(i) * 0.5, material: cm))
            for k in 0..<(detail ? 9 : 5) {
                let t = 0.5 + 0.5 * Float(k) / Float(detail ? 9 : 5)
                let p = FlowerKit.at(pts, t)
                for j in 0..<3 {
                    var b = PlantKit.Blade()
                    b.root = p; b.yaw = a + Float(k) * 2.2 + Float(j) * 0.9 + r.float(-0.3...0.3)
                    b.length = r.float(0.12...0.2); b.width = 0.016; b.lean = r.float(1.0...1.5); b.curl = r.float(0.3...0.8); b.fold = 0.2; b.belly = 0.6
                    b.segments = 3; b.u = V2(0, 0.016); b.v = V2(0, b.length); b.weight = V2(0.3, 0.9); b.phase = Float(i) * 0.5; b.ao = V2(0.5, 1)
                    lf.append(PlantKit.blade(b, material: lm))
                }
            }
        }
        m.add(st); m.add(lf)
        ShrubKit.finish(&m, height: 0.5, floor: 0.55)
        PlantKit.finish(&m)
        ShrubKit.clampGround(&m)
        return ShrubKit.centered(m)
    }
}
