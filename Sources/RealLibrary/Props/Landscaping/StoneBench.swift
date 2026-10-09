import simd
import Foundation

/// 1.4 m by 0.4 m seat at 0.45 m.
public struct StoneBench: RealAsset {
    public static let id = "stone-bench"
    public static let summary = "Limestone garden bench, 0.45 m: 1.4 m seat slab on two slab legs, moss at one foot."
    public static let tags = ["prop", "landscaping", "garden", "outdoor", "furniture", "stone"]
    public static let budget = 3000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 35, elevation: 18)
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let stone = "stone.limestone"
        m.add(Prim.roundedBox(V3(1.4, 0.07, 0.4), radius: 0.01, bevelSegments: 3, material: stone), Xform(translation: V3(0, 0.415, 0)))
        for s: Float in [-1, 1] {
            m.add(Prim.roundedBox(V3(0.12, 0.38, 0.34), radius: 0.008, bevelSegments: 2, material: stone), Xform(translation: V3(s * 0.5, 0.19, 0)))
        }
        m.add(Prim.superellipsoid(V3(0.2, 0.05, 0.3), exponent: 2, subdivisions: 5, material: "moss.cushion"), Xform(translation: V3(-0.5, 0.02, 0.02)))
        return K.finish(&m)
    }
}
