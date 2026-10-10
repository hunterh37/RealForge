import simd
import Foundation

/// Parked city bicycle, 1.75 m long and 1.05 m tall: step-through steel frame, 28-inch wheels, saddle, handlebar, kickstand.
public struct CityBicycle: RealAsset {
    public static let id = "city-bicycle"
    public static let summary = "Parked city bicycle, 1.75 m: step-through painted frame, spoked 28-inch wheels, saddle, bars and kickstand."
    public static let tags = ["prop", "urban", "street", "metal", "vehicle"]
    public static let budget = 6200
    public static let author = "hunterh37"

    /// Frame color, sRGB hex.
    public var frameColor: UInt32 = 0x2F6B57
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let paint = MaterialKey(stringLiteral: "metal.painted:" + String(frameColor, radix: 16, uppercase: true))
        let wr: Float = 0.34, rear = V3(-0.55, wr, 0), front = V3(0.55, wr, 0)
        for c in [rear, front] {
            m.add(Prim.torus(major: wr - 0.02, minor: 0.018, segments: 40, sides: 8, material: "rubber.tire"), Xform(translation: c, rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
            m.add(Prim.torus(major: wr - 0.045, minor: 0.006, segments: 40, sides: 6, material: "metal.aluminum-brushed"), Xform(translation: c, rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
            for i in 0..<16 {
                let a = Float(i) / 16 * .pi * 2
                rod(&m, c, c + V3(cos(a), sin(a), 0) * (wr - 0.05), 0.0015, "metal.steel", sides: 4)
            }
            m.add(Prim.cylinder(radius: 0.02, height: 0.1, bevel: 0.004, segments: 12, material: "metal.steel"), Xform(translation: c + V3(0, 0, -0.05), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
        }
        let bb = V3(0, 0.30, 0), seat = V3(-0.30, 0.95, 0), head = V3(0.42, 1.0, 0)
        for z: Float in [-0.05, 0.05] {
            rod(&m, rear + V3(0, 0, z), bb + V3(0, 0, z), 0.011, paint)
            rod(&m, rear + V3(0, 0, z), seat * V3(1, 1, 0) + V3(0, -0.12, z), 0.011, paint)
            rod(&m, front + V3(0, 0, z * 0.7), head + V3(0, -0.1, 0), 0.012, paint)
        }
        rod(&m, bb, V3(0.35, 0.86, 0), 0.016, paint)
        rod(&m, V3(0.35, 0.86, 0), head, 0.016, paint)
        rod(&m, bb, seat, 0.015, paint)
        rod(&m, head, head + V3(-0.05, 0.14, 0), 0.012, "metal.steel")
        rod(&m, head + V3(-0.05, 0.14, 0), head + V3(-0.08, 0.14, 0.3), 0.01, "metal.steel", sides: 8)
        rod(&m, head + V3(-0.05, 0.14, 0), head + V3(-0.08, 0.14, -0.3), 0.01, "metal.steel", sides: 8)
        for z: Float in [-0.3, 0.3] { rod(&m, head + V3(-0.08, 0.14, z), head + V3(-0.12, 0.14, z * 1.1), 0.014, "rubber.tire") }
        m.add(Prim.superellipsoid(V3(0.26, 0.05, 0.16), exponent: 3, material: "leather.black"), Xform(translation: seat + V3(0.0, 0.03 + rng.float(0...0.02), 0)))
        m.add(Prim.cylinder(radius: 0.06, height: 0.02, bevel: 0.004, segments: 20, material: "metal.steel"), Xform(translation: bb + V3(0, -0.01, 0.06), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
        rod(&m, bb, bb + V3(0.1, -0.12, 0.09), 0.008, "metal.steel", sides: 6)
        rod(&m, rear + V3(0.05, 0.02, 0.06), V3(-0.28, 0.0, 0.2), 0.008, "metal.steel", sides: 6)
        return K.finish(&m, ao: 0.1)
    }
}
