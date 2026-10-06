import simd
import Foundation

/// Informal American boxwood (Buxus sempervirens), about 0.95 m wide and 0.75 m tall: a lumpy mound
/// of small glossy leaves over a dark leaf-mass core, a few woody stems visible under the skirt.
public struct BoxwoodShrub: RealAsset {
    public static let id = "boxwood-shrub"
    public static let summary = "Informal American boxwood, 0.75 m: dense mound of small glossy leaves over a dark core, woody stems at the base."
    public static let tags = ["prop", "landscaping", "garden", "plant", "foliage", "outdoor"]
    public static let budget = 9000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 30, elevation: 15)

    /// Mound width (X/Z) and height, meters.
    public var width: Float = 0.95
    public var height: Float = 0.75
    /// Leaf-spray cards on the crown.
    public var sprays = 1600
    public var leaf: MaterialKey = "leaf.boxwood"
    public var mass: MaterialKey = "leaf.boxwood-mass"
    public var wood: MaterialKey = "bark.oak-dry"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        LODModel(levels: [model(seed: seed, detail: 1), model(seed: seed, detail: 0.4)], switchDistances: [9])
    }

    func model(seed: UInt64, detail: Float) -> Model {
        var rng = SeededRNG(seed: seed)
        let w = rng.vary(width, 0.06), h = rng.vary(height, 0.06)
        let card: Float = 0.15
        let crown = ShrubKit.Crown(center: V3(0, h * 0.4, 0), radii: V3(w / 2 - card * 0.3, h * 0.58 - card * 0.15, w / 2 - card * 0.3 - 0.02),
                                   exponent: 2.1, lumps: 0.75, lumpScale: 1.9, seed: rng.float(0...50), floorY: 0.05)
        var m = Model(name: Self.id)
        m.add(ShrubKit.core(crown, depth: 0.9, subdivisions: detail > 0.5 ? 10 : 6, material: mass))
        var r = rng.fork(1)
        let n = Int(Float(sprays) * detail)
        m.add(ShrubKit.sprays(crown, count: n, size: (card * 0.8)...(card * 1.15), depth: 0.84...1.03, minY: -0.75,
                              rng: &r, material: leaf))
        if detail > 0.5 {
            var s = rng.fork(2)
            m.add(ShrubKit.stems(count: 7, rootRadius: 0.08, crown: crown, reach: 0.5, radius: 0.008...0.016, rng: &s, material: wood))
        }
        ShrubKit.finish(&m, height: 0.25, floor: 0.45)
        return ShrubKit.fit(m, size: V3(w, h, w * 0.94))
    }
}
