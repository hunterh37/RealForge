import simd
import Foundation

/// Abstract white-model standing person for architectural scale, 1.75 m: capsule limbs, soft torso, round head.
public struct ScaleFigure: RealAsset {
    public static let id = "scale-figure"
    public static let summary = "Abstract white-model standing person, 1.75 m, for architectural scale: tapered limbs, torso and head."
    public static let tags = ["prop", "urban", "plastic"]
    public static let budget = 6400
    public static let author = "hunterh37"

    /// Standing height in meters.
    public var height: Float = 1.75
    /// Surface material key.
    public var material: String = "plastic.white"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let s = height * rng.vary(1, 0.03) / 1.75
        let mat = MaterialKey(stringLiteral: material)
        for side: Float in [-1, 1] {
            let hip = V3(side * 0.09 * s, 0.92 * s, 0), ankle = V3(side * 0.10 * s, 0.05 * s, 0)
            m.add(Prim.tube([hip, V3(side * 0.095 * s, 0.50 * s, 0.01), ankle], radii: [0.075 * s, 0.055 * s, 0.04 * s], sides: 14, seamTile: 0.3, material: mat))
            m.add(Prim.roundedBox(V3(0.09, 0.06, 0.25) * s, radius: 0.02, material: mat), Xform(translation: V3(side * 0.10 * s, 0.03 * s, 0.05 * s)))
            let sh = V3(side * 0.21 * s, 1.46 * s, 0), hand = V3(side * 0.26 * s, 0.80 * s, 0.03 * s)
            m.add(Prim.tube([sh, V3(side * 0.24 * s, 1.15 * s, 0.01), hand], radii: [0.045 * s, 0.037 * s, 0.028 * s], sides: 12, seamTile: 0.3, material: mat))
        }
        m.add(Prim.superellipsoid(V3(0.30, 0.20, 0.20) * s, exponent: 3, material: mat), Xform(translation: V3(0, 0.93 * s, 0)))
        m.add(Prim.superellipsoid(V3(0.42, 0.58, 0.24) * s, exponent: 3, material: mat), Xform(translation: V3(0, 1.22 * s, 0)))
        m.add(Prim.cylinder(radius: 0.05 * s, height: 0.10 * s, bevel: 0.01, segments: 16, material: mat), Xform(translation: V3(0, 1.48 * s, 0)))
        m.add(Prim.superellipsoid(V3(0.17, 0.23, 0.20) * s, exponent: 2, material: mat), Xform(translation: V3(0, 1.64 * s, 0.01)))
        return K.finish(&m, ao: 0.15)
    }
}
