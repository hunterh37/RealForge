import simd
import Foundation

/// Bigleaf hydrangea (Hydrangea macrophylla), about 1.2 m wide and 1.0 m tall: a loose mound of broad
/// serrated leaves on green stems, carrying 14-18 mophead flower heads 20-26 cm across at the canopy
/// surface, blue with a pink cast where the soil is less acid.
public struct HydrangeaBush: RealAsset {
    public static let id = "hydrangea-bush"
    public static let summary = "Bigleaf hydrangea, 1.0 m: mound of broad serrated leaves with 14-18 blue mophead flower heads."
    public static let tags = ["prop", "landscaping", "garden", "plant", "flower", "outdoor"]
    public static let budget = 15000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 30, elevation: 15)

    public var width: Float = 1.2
    public var height: Float = 1.0
    public var sprays = 820
    /// Mophead count range and head diameter range, meters.
    public var heads: ClosedRange<Int> = 14...18
    public var headDiameter: ClosedRange<Float> = 0.2...0.26
    public var leaf: MaterialKey = "leaf.hydrangea"
    public var flower: MaterialKey = "flower.hydrangea"
    public var mass: MaterialKey = "leaf.privet-mass"
    public var stem: MaterialKey = "plant.stem:4E5A2A"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        LODModel(levels: [model(seed: seed, detail: 1), model(seed: seed, detail: 0.4)], switchDistances: [10])
    }

    func model(seed: UInt64, detail: Float) -> Model {
        var rng = SeededRNG(seed: seed)
        let w = rng.vary(width, 0.06), h = rng.vary(height, 0.06)
        let card: Float = 0.3
        let crown = ShrubKit.Crown(center: V3(0, h * 0.42, 0), radii: V3(w / 2 - card * 0.3, h * 0.55, w / 2 - card * 0.3),
                                   exponent: 2, lumps: 0.6, lumpScale: 2.2, seed: rng.float(0...50), floorY: 0.08)
        var m = Model(name: Self.id)
        m.add(ShrubKit.core(crown, depth: 0.8, subdivisions: detail > 0.5 ? 8 : 5, material: mass))
        var a = rng.fork(1)
        m.add(ShrubKit.sprays(crown, count: Int(Float(sprays) * detail), size: (card * 0.8)...(card * 1.15), depth: 0.8...1.0,
                              minY: -0.6, tilt: 0.8, bend: 0.3...0.8, rng: &a, material: leaf))
        var b = rng.fork(2)
        // Each mophead: a dome of 5 floret clusters, hue drifting head to head (soil pH).
        var flowers = Model(name: "heads")
        let hues: [UInt32] = [0x4A62B0, 0x5E64B8, 0x4870B4, 0x6A68B4]
        for _ in 0..<b.int(heads) {
            var dir = b.unitVector(); dir.y = abs(dir.y) * 0.9 + 0.1; dir = simd_normalize(dir)
            let p = crown.point(dir, depth: 1.0)
            let d = b.float(headDiameter), R = d / 2
            let up = simd_normalize(crown.normal(p) + V3(0, 0.6, 0))
            let e1 = simd_normalize(up.anyPerpendicular), e2 = simd_cross(up, e1)
            let key: MaterialKey = flower + ":" + String(format: "%06X", hues[b.int(0...(hues.count - 1))])
            var head = Surface(material: key)
            let c0 = p + up * R * 0.5
            head.append(ShrubKit.floretBall(center: c0 + up * R * 0.25, radius: R * 0.6, up: up, subdivisions: detail > 0.5 ? 3 : 2,
                                            seed: b.float(0...40), material: key))
            let ring = 4
            for k in 0..<ring {
                let a = Float(k) / Float(ring) * 2 * .pi + b.float(-0.3...0.3)
                let off = (e1 * cos(a) + e2 * sin(a)) * R * 0.5
                head.append(ShrubKit.floretBall(center: c0 + off - up * R * 0.05, radius: R * b.float(0.48...0.56), up: up,
                                                subdivisions: detail > 0.5 ? 3 : 2, seed: b.float(0...40), material: key))
            }
            flowers.add(head)
        }
        m.add(flowers)
        if detail > 0.5 {
            var s = rng.fork(3)
            m.add(ShrubKit.stems(count: 9, rootRadius: 0.12, crown: crown, reach: 0.6, radius: 0.007...0.012, rng: &s, material: stem))
        }
        ShrubKit.finish(&m, height: 0.35, floor: 0.45)
        return ShrubKit.fit(m, size: V3(w, h, w * 0.99))
    }
}
