import simd
import Foundation

/// Civic statue plinth, 0.9 m square and 1.3 m tall: stepped stone base, moulded dado, cap, bronze abstract bust.
public struct StatuePlinth: RealAsset {
    public static let id = "statue-plinth"
    public static let summary = "Civic statue plinth, 1.3 m: stepped stone base, moulded dado and cap, bronze abstract bust on top."
    public static let tags = ["prop", "park", "urban", "stone", "decor"]
    public static let budget = 4100
    public static let author = "hunterh37"

    /// Plinth shaft width in meters.
    public var width: Float = 0.7
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let w = width, stone: MaterialKey = "concrete.exposed-aggregate"
        bx(&m, V3(w + 0.4, 0.10, w + 0.4), V3(0, 0.05, 0), stone, r: 0.012, bs: 2)
        bx(&m, V3(w + 0.24, 0.12, w + 0.24), V3(0, 0.16, 0), stone, r: 0.012, bs: 2)
        bx(&m, V3(w + 0.10, 0.08, w + 0.10), V3(0, 0.26, 0), stone, r: 0.01, bs: 2)
        bx(&m, V3(w, 0.72, w), V3(0, 0.66, 0), stone, r: 0.008, bs: 2)
        bx(&m, V3(w + 0.10, 0.06, w + 0.10), V3(0, 1.05, 0), stone, r: 0.01, bs: 2)
        bx(&m, V3(w + 0.20, 0.10, w + 0.20), V3(0, 1.13, 0), stone, r: 0.012, bs: 2)
        bx(&m, V3(w - 0.2, 0.012, w - 0.2), V3(0, 0.66, w / 2 + 0.003), "metal.bronze-cast", r: 0.002)
        let tilt = rng.float(-6...6)
        m.add(turned([(0, 0), (0.17, 0), (0.2, 0.04), (0.14, 0.12), (0.2, 0.26), (0.22, 0.32)], segments: 28, material: "metal.bronze-cast"),
              Xform(translation: V3(0, 1.18, 0), rotation: simd_quatf(degrees: tilt, axis: .up)))
        m.add(Prim.superellipsoid(V3(0.3, 0.34, 0.3), exponent: 2, material: "metal.bronze-cast"), Xform(translation: V3(0, 1.62, 0)))
        return K.finish(&m, ao: 0.3)
    }
}
