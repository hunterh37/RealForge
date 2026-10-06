import simd
import Foundation

/// Emerald Green arborvitae (Thuja occidentalis 'Smaragd'), nursery landscape size: 2.4 m tall, 0.9 m
/// wide narrow pyramid of flat scale-foliage sprays over a dark core, slightly irregular outline and a
/// soft pointed leader, short trunk and dark interior showing at the base.
public struct Arborvitae: RealAsset {
    public static let id = "arborvitae"
    public static let summary = "Emerald Green arborvitae, 2.4 m: narrow pyramidal column of flat scale-foliage sprays over a dark core."
    public static let tags = ["prop", "landscaping", "garden", "plant", "conifer", "outdoor"]
    public static let budget = 13000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 30, elevation: 10)

    public var height: Float = 2.4
    public var width: Float = 0.9
    public var sprays = 2500
    public var leaf: MaterialKey = "leaf.cypress"
    public var mass: MaterialKey = "leaf.arborvitae-mass"
    public var bark: MaterialKey = "bark.cypress"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        LODModel(levels: [model(seed: seed, detail: 1), model(seed: seed, detail: 0.4)], switchDistances: [14])
    }

    func model(seed: UInt64, detail: Float) -> Model {
        var rng = SeededRNG(seed: seed)
        let h = rng.vary(height, 0.05), w = rng.vary(width, 0.06)
        let card: Float = 0.24
        let crown = ShrubKit.Crown(center: V3(0, h * 0.5 + 0.04, 0), radii: V3(w / 2 - card * 0.25, h * 0.5 - 0.04, w / 2 - card * 0.25),
                                   exponent: 2.6, lumps: 0.35, lumpScale: 2.4, seed: rng.float(0...50), floorY: 0.12,
                                   taper: { t in max(0.06, (1 - pow(t, 1.9)) * (0.82 + 0.18 * smoothstep(0, 0.25, t))) })
        var m = Model(name: Self.id)
        m.add(ShrubKit.core(crown, depth: 0.9, subdivisions: detail > 0.5 ? 12 : 7, material: mass))
        var a = rng.fork(1)
        var cards = Surface(material: leaf)
        let top = h
        for _ in 0..<Int(Float(sprays) * detail) {
            var spot = ShrubKit.crownSpot(crown, rng: &a, depth: 0.84...1.03, minY: -0.92)
            // Sprays are flattened vertical fans that stand up and out along the column.
            spot.n = simd_normalize(spot.n + V3(0, 0.25, 0))
            let s = a.float((card * 0.8)...(card * 1.15))
            ShrubKit.card(&cards, spot: spot, width: s * 0.8, height: s, tilt: 0.6, bend: a.float(0.1...0.45), rng: &a, top: top, windScale: 0.6)
        }
        m.add(cards)
        if detail > 0.5 {
            let trunk = Prim.tube([V3(0, 0, 0), V3(0.005, 0.25, 0), V3(0, 0.6, 0.004)], radii: [0.035, 0.03, 0.022], sides: 8, seamTile: 0.1, material: bark)
            m.add(trunk)
        }
        ShrubKit.finish(&m, height: 0.4, floor: 0.45)
        return ShrubKit.fit(m, size: V3(w, h, w * 0.99))
    }
}
