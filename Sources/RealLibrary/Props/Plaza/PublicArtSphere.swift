import simd
import Foundation

/// Polished steel sphere sculpture, 2.4 m across on a 0.45 m stone plinth: mirror finish, recessed collar, honed base.
public struct PublicArtSphere: RealAsset {
    public static let id = "public-art-sphere"
    public static let summary = "Public art sphere, 2.4 m: mirror-polished steel ball on a honed stone plinth with a recessed collar."
    public static let tags = ["prop", "city", "park", "urban", "outdoor", "metal"]
    public static let budget = 3500
    public static let author = "hunterh37"

    /// Sphere radius in meters.
    public var radius: Float = 1.2
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        K.box(&m, V3(0, 0.225, 0), V3(1.9, 0.45, 1.9), "stone.cap", bevel: 0.025)
        K.box(&m, V3(0, 0.47, 0), V3(1.5, 0.04, 1.5), "stone.cap", bevel: 0.012)
        var prof: [(Float, Float)] = []
        for i in 0...24 {
            let a = Float(i) / 24 * .pi
            prof.append((max(0.001, sin(a) * radius), radius - cos(a) * radius))
        }
        m.add(turned(prof, segments: 48, material: "metal.mirror-polish"), Xform(translation: V3(0, 0.45 + 0.02, 0)))
        m.add(Prim.torus(major: 0.2, minor: 0.012, segments: 24, sides: 8, material: "metal.steel"), Xform(translation: V3(0, 0.5, 0)))
        return K.finish(&m, ao: 0.25)
    }
}
