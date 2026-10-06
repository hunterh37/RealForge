import simd
import Foundation

/// Evergreen azalea in full spring bloom, about 1.0 m wide and 0.85 m tall: a mound of small elliptic
/// leaves nearly hidden under clusters of three to five hot-pink funnel flowers, 5 cm across with five
/// flared lobes, at the branch tips.
public struct KnockoutAzalea: RealAsset {
    public static let id = "knockout-azalea"
    public static let summary = "Evergreen azalea in bloom, 0.85 m: mound of small leaves covered in clusters of pink funnel flowers."
    public static let tags = ["prop", "landscaping", "garden", "plant", "flower", "outdoor"]
    public static let budget = 14500
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 30, elevation: 18)

    public var width: Float = 1.0
    public var height: Float = 0.85
    public var sprays = 700
    /// Flower clusters on the crown surface (3-5 flowers each).
    public var clusters = 125
    public var flowerDiameter: Float = 0.058
    public var leaf: MaterialKey = "leaf.azalea"
    public var flower: MaterialKey = "flower.azalea"
    public var mass: MaterialKey = "leaf.boxwood-mass"
    public var stem: MaterialKey = "plant.stem:4A3E26"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        LODModel(levels: [model(seed: seed, detail: 1), model(seed: seed, detail: 0.4)], switchDistances: [9])
    }

    func model(seed: UInt64, detail: Float) -> Model {
        var rng = SeededRNG(seed: seed)
        let w = rng.vary(width, 0.06), h = rng.vary(height, 0.06)
        let card: Float = 0.16
        let crown = ShrubKit.Crown(center: V3(0, h * 0.4, 0), radii: V3(w / 2 - card * 0.3, h * 0.58, w / 2 - card * 0.3),
                                   exponent: 2.2, lumps: 0.5, lumpScale: 2.4, seed: rng.float(0...50), floorY: 0.06)
        var m = Model(name: Self.id)
        m.add(ShrubKit.core(crown, depth: 0.88, subdivisions: detail > 0.5 ? 8 : 5, material: mass))
        var a = rng.fork(1)
        m.add(ShrubKit.sprays(crown, count: Int(Float(sprays) * detail), size: (card * 0.8)...(card * 1.15), depth: 0.84...1.02,
                              minY: -0.7, tilt: 0.7, bend: 0.2...0.6, rng: &a, material: leaf))
        var b = rng.fork(2)
        var flowers = Surface(material: flower)
        let nClusters = Int(Float(clusters) * (detail > 0.5 ? 1 : 0.35))
        let d = flowerDiameter
        for _ in 0..<nClusters {
            var dir = b.unitVector(); dir.y = dir.y * 0.8 + 0.25; dir = simd_normalize(dir)
            let p = crown.point(dir, depth: 1.0)
            let n = crown.normal(p)
            let tangent = simd_normalize(simd_cross(n, n.anyPerpendicular))
            for k in 0..<b.int(3...7) {
                let ang = Float(k) * 2.1 + b.float(-0.4...0.4)
                let off = simd_quatf(angle: ang, axis: n).act(tangent) * d * b.float(0.4...0.7)
                let face = simd_normalize(n + off / d * 0.8 + b.unitVector() * 0.25)
                ShrubKit.starFlower(&flowers, center: p + off + n * 0.008, normal: face, radius: b.vary(d / 2, 0.12), lobes: 5,
                                    cup: 0.28, throat: 0.018, spin: b.float(0...6.28), weight: 0.5, phase: b.float(0...1))
            }
        }
        m.add(flowers)
        if detail > 0.5 {
            var s = rng.fork(3)
            m.add(ShrubKit.stems(count: 8, rootRadius: 0.1, crown: crown, reach: 0.55, radius: 0.007...0.013, rng: &s, material: stem))
        }
        ShrubKit.finish(&m, height: 0.3, floor: 0.45)
        return ShrubKit.fit(m, size: V3(w, h, w * 0.99))
    }
}
