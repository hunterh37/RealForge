import simd
import Foundation

/// Common milkweed (Asclepias syriaca), 0.9 m: one stout downy stem with opposite broad oval leaves
/// (pale undersides, pink midribs), drooping umbels of dusky-pink flowers near the top and a warty
/// green seed pod. Host plant of the monarch.
public struct Milkweed: RealAsset {
    public static let id = "milkweed"
    public static let summary = "Common milkweed, 0.9 m: stout stem, opposite broad oval leaves, dusky-pink flower umbels, warty seed pod."
    public static let tags = ["prop", "plant", "flower", "garden", "outdoor"]
    public static let budget = 12_000
    public static let preview = PreviewHint(azimuth: 30, elevation: 12, distance: 1.0)

    public var height: Float = 0.9
    public var leaf: MaterialKey = "leaf.milkweed"
    public var stem: MaterialKey = "plant.stem:7A8A5A"
    public var flower: MaterialKey = "flower.azalea:C8809A"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        LODModel(levels: [model(seed: seed, detail: true), model(seed: seed, detail: false)], switchDistances: [7])
    }

    func model(seed: UInt64, detail: Bool) -> Model {
        var rng = SeededRNG(seed: seed)
        let H = rng.vary(height, 0.05)
        let lean = V3(rng.float(-0.04...0.04), 0, rng.float(-0.04...0.04))
        func at(_ t: Float) -> V3 { V3(0, t * H, 0) + lean * t * t }
        var m = Model(name: Self.id)
        let pts = (0...8).map { at(Float($0) / 8) }
        m.add(InsectKit.limb(pts, radii: pts.indices.map { 0.0065 - 0.0035 * Float($0) / 8 }, material: stem, sides: detail ? 8 : 5, per: detail ? 2 : 1))
        // Opposite leaf pairs, decussate, shrinking toward the top.
        let pairs = 9
        for i in 0..<pairs {
            let t = 0.16 + 0.72 * Float(i) / Float(pairs - 1)
            let base = at(t)
            let yaw = Float(i) * .pi / 2 + rng.float(-0.2...0.2)
            let len = (0.19 - 0.09 * t) * rng.float(0.9...1.1)
            for s: Float in [1, -1] {
                let dir = V3(cos(yaw) * s, 0, sin(yaw) * s)
                let span = simd_normalize(dir + V3(0, 0.12 - t * 0.1, 0))
                let chord = simd_normalize(simd_cross(V3(0, 1, 0), dir))
                for var sf in InsectKit.wing(.katydidTegmen, root: base + dir * 0.005, span: span, chord: chord, length: len, width: len * 0.7, rootV: 0.55,
                                             material: leaf, droop: len * 0.25, cup: len * 0.06) {
                    // Caterpillar feeding: a bite out of the margin on some lower leaves.
                    if i < 5 && rng.chance(0.5) {
                        let bite = V2(rng.float(0.45...0.8), rng.chance(0.5) ? 0.95 : 0.1), br = rng.float(0.12...0.2)
                        var keep: [UInt32] = []
                        for t in stride(from: 0, to: sf.indices.count, by: 3) {
                            let c = (sf.uvs[Int(sf.indices[t])] + sf.uvs[Int(sf.indices[t + 1])] + sf.uvs[Int(sf.indices[t + 2])]) / 3
                            if simd_distance(c, bite) > br { keep += sf.indices[t..<(t + 3)] }
                        }
                        sf.indices = keep
                    }
                    m.add(sf)
                }
                m.add(InsectKit.limb([base, base + dir * 0.008], radii: [0.002, 0.0015], material: stem, sides: 4, per: 1))
            }
        }
        // Flower umbels: stalked balls of small star flowers drooping from the upper axils.
        var fl = Surface(material: flower)
        let umbels = detail ? 4 : 2
        for u in 0..<umbels {
            let t: Float = 0.78 + 0.05 * Float(u)
            let base = at(t)
            let a = Float(u) * 2.4 + rng.float(-0.3...0.3)
            let out = V3(cos(a), 0, sin(a))
            let c = base + out * 0.07 + V3(0, 0.025, 0)
            m.add(InsectKit.limb([base, base + out * 0.03 + V3(0, 0.03, 0), c], radii: [0.002, 0.0016, 0.0012], material: stem, sides: 4, per: 1))
            let n = detail ? 44 : 14
            for k in 0..<n {
                var d = rng.unitVector(); d.y = d.y * 0.6 - 0.25; d = simd_normalize(d)
                let p = c + d * 0.036
                if detail { m.add(InsectKit.limb([c, p], radii: [0.0006, 0.0005], material: "plant.stem:9A8A6A", sides: 3, per: 1)) }
                ShrubKit.starFlower(&fl, center: p, normal: d, radius: 0.0058, lobes: 5, cup: -0.5, throat: 0.002, spin: Float(k), weight: 0.6, phase: 0)
            }
        }
        m.add(fl)
        if detail {
            // Seed pod: warty spindle from a lower axil.
            let b = at(0.55), dir = simd_normalize(V3(0.5, 0.8, 0.2))
            let pod = InsectKit.blob(b + dir * 0.05, V3(0.012, 0.012, 0.045), material: "plant.stem:6E8A4A", sub: 6,
                                     rot: simd_quatf(from: V3(0, 0, 1), to: dir)) { q in q * (1 + 0.04 * max(0, sin(q.x * 900) * sin(q.z * 400))) * V3(1, 1, 1) * (1 - max(0, q.z) * 8) + V3(0, 0, 0) }
            m.add(pod)
        }
        groundAO(&m, height: 0.2, floor: 0.6)
        return m
    }
}
