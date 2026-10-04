import simd
import Foundation

/// Glazed ceramic office mug, 85 mm across and 95 mm tall (about 330 ml): thrown body with a slight
/// belly, rolled rim, unglazed foot ring under a recessed base, D-shaped pulled handle with an oval
/// section, coffee filled to 25 mm below the rim.
public struct CoffeeMug: RealAsset {
    public static let id = "coffee-mug"
    public static let summary = "Glazed ceramic office mug, 85 mm by 95 mm: thrown body with rolled rim and foot ring, pulled oval handle, coffee inside."
    public static let tags = ["prop", "office", "ceramic", "kitchen"]
    public static let budget = 2_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 30, elevation: 22, distance: 0.3, studio: true)

    public var glaze: MaterialKey = "ceramic.stoneware:ECE8E0"
    public var radius: Float = 0.0425
    public var height: Float = 0.095
    /// Coffee level below the rim (m); nil = empty.
    public var fillDrop: Float? = 0.024
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        _ = seed
        var levels: [Model] = []
        let R = radius, H = height
        for l in 0..<2 {
            var m = Model(name: Self.id)
            let segs = l == 0 ? 32 : 16
            // Body: recessed underside, foot ring, outer wall, rolled rim, inner wall, inner floor.
            let p: [V2] = [
                V2(0, 0.0032), V2(R * 0.62, 0.0032), V2(R * 0.68, 0.0018), V2(R * 0.715, 0.0002), V2(R * 0.78, 0),
                V2(R * 0.83, 0.0012), V2(R * 0.89, 0.0062), V2(R * 0.965, 0.018), V2(R * 0.99, 0.032),
                V2(R, H * 0.55), V2(R * 0.998, H - 0.004), V2(R * 0.992, H - 0.0015), V2(R * 0.975, H), V2(R * 0.955, H - 0.0006),
                V2(R * 0.935, H - 0.005), V2(R * 0.93, H * 0.55), V2(R * 0.9, 0.024), V2(R * 0.82, 0.0135),
                V2(R * 0.6, 0.0105), V2(0, 0.0102),
            ]
            m.add(Prim.lathe(p, segments: segs, seamTile: 0.3, material: glaze))
            // Handle: oval section swept along a D curve on +X, ends buried in the wall.
            let path = catmull([V3(R - 0.004, H * 0.83, 0), V3(R + 0.016, H * 0.82, 0), V3(R + 0.03, H * 0.66, 0),
                                V3(R + 0.03, H * 0.44, 0), V3(R + 0.017, H * 0.28, 0), V3(R - 0.004, H * 0.24, 0)], per: l == 0 ? 4 : 2)
            let sec = Shape2D.superellipse(0.013, 0.0075, exponent: 2.4, segments: l == 0 ? 12 : 8)
            let scales = path.indices.map { i -> Float in
                let t = Float(i) / Float(path.count - 1)
                return 1 + 0.18 * (abs(t - 0.5) * 2)          // thickens where it joins the body
            }
            m.add(Prim.sweep(sec, along: path, up: V3(0, 0, 1), scales: scales, material: glaze))
            if let drop = fillDrop {
                let y = H - drop, r = R * 0.93 - 0.0002
                m.add(Prim.lathe([V2(r, y + 0.0008), V2(r - 0.002, y), V2(0, y)], segments: segs, seamTile: 0.3, material: "plastic.gloss:24130A"))
            }
            groundAO(&m, height: 0.02, floor: 0.6)
            let bb = m.bounds
            levels.append(m.transformed(Xform(translation: V3(-(bb.min.x + bb.max.x) / 2, 0, 0))))
        }
        return LODModel(levels: levels, switchDistances: [3])
    }
}
