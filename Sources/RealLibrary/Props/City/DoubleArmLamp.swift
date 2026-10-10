import simd
import Foundation

/// Double-arm street lamp, 8 m tall: tapered galvanized pole on a base plate, two curved arms with cobra-head luminaires.
public struct DoubleArmLamp: RealAsset {
    public static let id = "double-arm-lamp"
    public static let summary = "Double-arm street lamp, 8 m: tapered pole on a bolted base, two curved arms, cobra-head luminaires with lit lenses."
    public static let tags = ["prop", "city", "street", "road", "urban", "light", "metal"]
    public static let budget = 2000
    public static let author = "hunterh37"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        K.box(&m, V3(0, 0.02, 0), V3(0.36, 0.04, 0.36), "metal.galvanized", bevel: 0.006)
        m.add(turned([(0.14, 0.04), (0.14, 0.12), (0.09, 0.3), (0.07, 4.0), (0.055, 7.8), (0.0, 7.8)], segments: 20, material: "metal.galvanized"))
        for (x, z): (Float, Float) in [(-0.14, -0.14), (0.14, -0.14), (0.14, 0.14), (-0.14, 0.14)] {
            m.add(Prim.cylinder(radius: 0.018, height: 0.03, bevel: 0.003, segments: 8, material: "metal.steel"), Xform(translation: V3(x, 0.04, z)))
        }
        for s: Float in [-1, 1] {
            let pts = K.arc(V3(s * 0.6, 7.7, 0), 0.6, s > 0 ? 180 : 0, s > 0 ? 80 : 100, n: 10)
            K.rod(&m, pts, r: 0.035, "metal.galvanized", sides: 8)
            let end = pts.last!
            K.box(&m, end + V3(s * 0.2, -0.05, 0), V3(0.7, 0.1, 0.3), "metal.painted:6B6F73", bevel: 0.03)
            K.box(&m, end + V3(s * 0.2, -0.115, 0), V3(0.6, 0.03, 0.24), "emissive.warm", bevel: 0.006)
        }
        return K.finish(&m, ao: 0.1)
    }
}
