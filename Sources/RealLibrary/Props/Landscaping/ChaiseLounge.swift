import simd
import Foundation

/// 0.65 m wide, 1.9 m long, 0.35 m seat height, back reclined at 45 degrees.
public struct ChaiseLounge: RealAsset {
    public static let id = "chaise-lounge"
    public static let summary = "Chaise lounge, 0.9 m: cedar slat frame with reclined back, canvas cushions, four legs and rear wheels."
    public static let tags = ["prop", "landscaping", "garden", "outdoor", "furniture", "wood"]
    public static let budget = 9000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 35, elevation: 18)
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let wood = "wood.cedar-weathered"
        let back = simd_quatf(degrees: 45, axis: V3(1, 0, 0))
        for s: Float in [-1, 1] {
            K.beam(&m, V3(s * 0.31, 0.32, -0.1), V3(s * 0.31, 0.32, 1.25), 0.05, 0.04, wood)
            K.beam(&m, V3(s * 0.31, 0.34, -0.1), V3(s * 0.31, 0.9, -0.63), 0.05, 0.035, wood, up: V3(0, 0.7, 0.7))
            for z: Float in [-0.05, 1.2] { K.box(&m, V3(s * 0.31, 0.15, z), V3(0.05, 0.3, 0.05), wood) }
        }
        for i in 0..<18 { K.box(&m, V3(0, 0.355, -0.05 + 0.075 * Float(i)), V3(0.6, 0.018, 0.06), wood, bevel: 0.002) }
        let d = V3(0, sin(.pi / 4), -cos(.pi / 4))
        for i in 0..<10 { K.box(&m, V3(0, 0.36, -0.1) + d * (0.07 + 0.075 * Float(i)) + V3(0, 0.0, 0), V3(0.6, 0.018, 0.06), wood, bevel: 0.002, rot: back) }
        m.add(Prim.superellipsoid(V3(0.56, 0.08, 1.3), exponent: 6, subdivisions: 8, material: "fabric.canvas"), Xform(translation: V3(0, 0.41, 0.58)))
        m.add(Prim.superellipsoid(V3(0.56, 0.07, 0.75), exponent: 6, subdivisions: 8, material: "fabric.canvas"),
              Xform(translation: V3(0, 0.36, -0.1) + d * 0.4 + V3(0, 0.05, 0.03), rotation: back))
        for s: Float in [-1, 1] {
            m.add(Prim.cylinder(radius: 0.05, height: 0.03, bevel: 0.004, segments: 16, material: "rubber.tire"),
                  Xform(translation: V3(s * 0.345, 0.05, 1.2), rotation: simd_quatf(degrees: 90, axis: V3(0, 0, 1))))
        }
        return K.finish(&m)
    }
}
