import simd
import Foundation

/// Compact tracked excavator, 4.3 m long with the arm extended, 1.7 m wide, 2.5 m tall: rubber tracks, cab, boom, dipper, bucket, dozer blade.
public struct MiniExcavator: RealAsset {
    public static let id = "mini-excavator"
    public static let summary = "Compact tracked excavator, 4.3 m: rubber tracks, glass cab, boom, dipper arm, bucket, dozer blade, hydraulic rams."
    public static let tags = ["prop", "vehicle", "construction", "industrial", "metal"]
    public static let budget = 4500
    public static let author = "hunterh37"

    /// Body paint, sRGB hex.
    public var color: UInt32 = 0xF2B705
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let p = SK.paint(color), dark = "metal.painted:2A2B2D"
        for s: Float in [-1, 1] {
            K.box(&m, V3(s * 0.62, 0.22, 0), V3(0.44, 0.44, 2.25), "rubber.tire", bevel: 0.08)
            for z: Float in [-0.95, 0.95] {
                m.add(Prim.cylinder(radius: 0.2, height: 0.46, bevel: 0.01, segments: 16, material: "metal.painted:2A2B2D"),
                      Xform(translation: V3(s * 0.62 + 0.23, 0.22, z), rotation: simd_quatf(degrees: 90, axis: V3(0, 0, 1))))
            }
        }
        K.box(&m, V3(0, 0.5, 0), V3(1.0, 0.24, 1.9), dark, bevel: 0.02)
        m.add(Prim.cylinder(radius: 0.55, height: 0.1, bevel: 0.01, segments: 24, material: "metal.steel"), Xform(translation: V3(0, 0.62, 0)))
        K.box(&m, V3(0, 1.0, -0.4), V3(1.5, 0.7, 1.15), p, bevel: 0.04)
        K.box(&m, V3(0, 0.85, -0.95), V3(1.46, 0.5, 0.2), "metal.painted:1E1E20", bevel: 0.03)
        K.box(&m, V3(-0.4, 1.58, 0.1), V3(0.7, 0.5, 0.9), "glass.tinted", bevel: 0.01)
        K.box(&m, V3(-0.4, 1.5, 0.1), V3(0.74, 0.1, 0.94), p, bevel: 0.02)
        K.box(&m, V3(-0.4, 2.05, 0.1), V3(0.84, 0.06, 1.0), p, bevel: 0.015)
        for (x, z): (Float, Float) in [(-0.04, -0.35), (-0.76, -0.35), (-0.04, 0.5), (-0.76, 0.5)] {
            K.box(&m, V3(x, 1.8, z), V3(0.05, 0.5, 0.05), p, bevel: 0.01)
        }
        let bx0: Float = 0.45, pivot = V3(bx0, 0.95, 0.4), knee = V3(bx0, 2.0, 2.0), tip = V3(bx0, 0.55, 3.4)
        K.beam(&m, pivot, knee, 0.22, 0.26, p, up: V3(1, 0, 0))
        K.beam(&m, knee, tip, 0.16, 0.2, p, up: V3(1, 0, 0))
        K.rod(&m, [V3(bx0, 1.1, 0.2), V3(bx0, 1.6, 1.3)], r: 0.05, "metal.chrome", sides: 10)
        K.rod(&m, [V3(bx0, 1.9, 1.3), V3(bx0, 1.75, 2.3)], r: 0.04, "metal.chrome", sides: 8)
        SK.side(&m, [V2(3.3, 0.7), V2(3.55, 0.72), V2(3.95, 0.35), V2(3.9, 0.12), V2(3.4, 0.1), V2(3.25, 0.4)], width: 0.6, x: bx0, mat: dark, bevel: 0.015)
        K.box(&m, V3(0, 0.3, 1.5), V3(1.7, 0.28, 0.14), dark, bevel: 0.02)
        return K.finish(&m, ao: 0.3)
    }
}
