import simd
import Foundation

/// 1.5 m pole, 40 mm diameter, fuel canister 100 mm.
public struct TikiTorch: RealAsset {
    public static let id = "tiki-torch"
    public static let summary = "Tiki torch, 1.8 m: bamboo pole with node rings, copper fuel canister, wick and a lit flame."
    public static let tags = ["prop", "landscaping", "garden", "outdoor", "light", "wood"]
    public static let budget = 2500
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 35, elevation: 18)
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let bamboo = "wood.lumber-maple"
        m.add(Prim.cylinder(radius: 0.02, height: 1.5, bevel: 0.003, segments: 12, material: bamboo, grainVertical: true))
        for y: Float in [0.3, 0.62, 0.95, 1.25] {
            m.add(Prim.torus(major: 0.021, minor: 0.006, segments: 12, sides: 6, material: bamboo), Xform(translation: V3(0, y, 0)))
        }
        m.add(Prim.cylinder(radius: 0.05, height: 0.08, bevel: 0.006, segments: 20, material: "metal.copper-patina"), Xform(translation: V3(0, 1.5, 0)))
        m.add(Prim.cylinder(radius: 0.012, height: 0.05, bevel: 0.002, segments: 8, material: "metal.painted:EDEAD8"), Xform(translation: V3(0, 1.58, 0)))
        m.add(turned([(0, 0), (0.026, 0.02), (0.022, 0.08), (0.009, 0.14), (0, 0.17)], segments: 12, material: "emissive.flame", seamTile: 0.1),
              Xform(translation: V3(0, 1.63, 0)))
        return K.finish(&m)
    }
}
