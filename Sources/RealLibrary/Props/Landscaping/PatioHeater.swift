import simd
import Foundation

/// 0.48 m base, 0.34 m tank housing, 0.82 m reflector.
public struct PatioHeater: RealAsset {
    public static let id = "patio-heater"
    public static let summary = "Standing propane patio heater, 2.25 m: weighted painted base housing the tank, steel pole, burner and wide domed reflector."
    public static let tags = ["prop", "landscaping", "garden", "outdoor", "appliance", "metal"]
    public static let budget = 4500
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 35, elevation: 18)
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let paint = "metal.painted:3A3A3E", steel = "metal.stainless"
        m.add(Prim.cylinder(radius: 0.24, height: 0.04, bevel: 0.006, segments: 32, material: paint))
        m.add(Prim.cylinder(radius: 0.17, height: 0.74, bevel: 0.01, segments: 28, material: paint), Xform(translation: V3(0, 0.04, 0)))
        K.box(&m, V3(0, 0.4, 0.168), V3(0.14, 0.4, 0.008), "metal.painted:2A2A2D", bevel: 0.002)
        m.add(Prim.cylinder(radius: 0.025, height: 1.3, bevel: 0.003, segments: 14, material: steel), Xform(translation: V3(0, 0.78, 0)))
        m.add(Prim.cylinder(radius: 0.035, height: 0.2, bevel: 0.004, segments: 16, material: steel), Xform(translation: V3(0, 2.0, 0)))
        m.add(turned([(0.0, 2.27), (0.1, 2.265), (0.26, 2.2), (0.4, 2.08), (0.41, 2.065), (0.395, 2.065), (0.25, 2.13), (0.1, 2.18), (0.0, 2.185)],
                     segments: 40, material: steel))
        return K.finish(&m)
    }
}
