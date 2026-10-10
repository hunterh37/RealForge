import simd
import Foundation

/// Historic tie-rod anchor star: an eight-point cast-iron star plate with a domed center nut,
/// a short wedge-key bar and rust bloom, as set into a brick wall at floor lines. 0.36 m across.
/// Wall plane at z = 0.
public struct TieRodAnchorStar: RealAsset {
    public static let id = "tie-rod-anchor-star"
    public static let summary = "Tie-rod anchor star, 0.36 m: eight-point cast-iron plate, domed nut, wedge key, rust bloom."
    public static let tags = ["prop", "architecture", "facade", "ornament", "metal"]
    public static let budget = 4_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 28, elevation: 8, distance: 1.1)

    public var diameter: Float = 0.36
    public var points: Int = 8
    public var iron: MaterialKey = "metal.cast-iron"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let R = diameter / 2, n = max(4, points), cy = R
        var star: [V2] = []
        for i in 0..<(n * 2) {
            let a = Float(i) / Float(n * 2) * 2 * .pi
            let r = i % 2 == 0 ? R : R * 0.42
            star.append(V2(cos(a) * r, sin(a) * r))
        }
        m.add(Prim.extrude(Shape2D.rounded(star, radius: 0.012, segments: 2), depth: 0.026, bevel: 0.005, bevelSegments: 1, material: iron),
              Xform(translation: V3(0, cy, 0.013), rotation: FA.q(90 / Float(n) * 0, FA.Z)))
        m.add(Prim.torus(major: R * 0.34, minor: 0.012, segments: 24, sides: 6, material: iron), Xform(translation: V3(0, cy, 0.034), rotation: FA.q(90, FA.X)))
        m.add(Prim.lathe([V2(0, 0), V2(0.06, 0), V2(0.058, 0.02), V2(0.04, 0.04), V2(0, 0.048)], segments: 14, material: iron),
              Xform(translation: V3(0, cy, 0.028), rotation: FA.q(90, FA.X)))
        // Wedge key through a slot in the nut.
        FA.box(&m, V3(0.2, 0.02, 0.016), V3(0, cy, 0.06), "metal.rust", r: 0.003, rot: FA.q(rng.float(-4...4), FA.Z))
        for i in 0..<n {
            let a = Float(i) / Float(n) * 2 * .pi
            FC.bead(&m, r: 0.01, at: V3(cos(a) * R * 0.78, cy + sin(a) * R * 0.78, 0.028), "metal.rust")
        }
        // Rust drip stain below.
        FA.box(&m, V3(0.06, 0.18, 0.002), V3(0.02, cy - R * 1.1, 0.002), "metal.rust", r: 0.0005)
        groundAO(&m, height: 0.06, floor: 0.9)
        return LODModel(FC.place(m))
    }
}
