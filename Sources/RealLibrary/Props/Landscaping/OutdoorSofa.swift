import simd
import Foundation

public struct OutdoorSofa: RealAsset {
    public static let id = "outdoor-sofa"
    public static let summary = "Outdoor wicker sofa, 2.0 x 0.8 x 0.8 m: rattan frame with two seat cushions and two back cushions."
    public static let tags = ["prop", "landscaping", "outdoor", "furniture"]
    public static let budget = 9000
    public static let author = "realityhd"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let r = "wicker.willow", c = "fabric.canvas"
        K.box(&m, V3(0, 0.22, 0), V3(2.0, 0.2, 0.8), r, bevel: 0.02)
        K.box(&m, V3(0, 0.55, -0.36), V3(2.0, 0.55, 0.08), r, bevel: 0.02)
        for s: Float in [-1, 1] { K.box(&m, V3(s * 0.94, 0.42, 0), V3(0.12, 0.35, 0.8), r, bevel: 0.02) }
        for x: Float in [-0.45, 0.45] {
            m.add(Prim.superellipsoid(V3(0.84, 0.16, 0.66), exponent: 4, subdivisions: 5, material: c), Xform(translation: V3(x, 0.4, 0.03)))
            m.add(Prim.superellipsoid(V3(0.8, 0.45, 0.14), exponent: 4, subdivisions: 5, material: c), Xform(translation: V3(x, 0.62, -0.22), rotation: simd_quatf(degrees: -12, axis: V3(1, 0, 0))))
        }
        for x: Float in [-0.9, 0.9] { for z: Float in [-0.35, 0.35] { K.box(&m, V3(x, 0.06, z), V3(0.06, 0.12, 0.06), r) } }
        return K.finish(&m)
    }
}
