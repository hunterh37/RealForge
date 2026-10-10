import simd
import Foundation

/// Small horizontal-axis wind turbine, 3.2 m rotor on a 4.5 m mast: tapered tube, nacelle, three composite blades, tail vane, base flange.
public struct SmallWindTurbine: RealAsset {
    public static let id = "small-wind-turbine"
    public static let summary = "Small wind turbine, 3.2 m rotor: tapered white mast on a flange, nacelle, hub with three blades, tail vane."
    public static let tags = ["prop", "roof", "urban", "outdoor", "metal"]
    public static let budget = 1600
    public static let author = "hunterh37"

    /// Rotor angle in degrees.
    public var rotorAngle: Float = 20
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let white = SK.paint(0xF0F0EC), top: Float = 4.5
        K.box(&m, V3(0, 0.02, 0), V3(0.5, 0.04, 0.5), "metal.galvanized", bevel: 0.006)
        m.add(turned([(0.1, 0.04), (0.1, 0.1), (0.07, 0.4), (0.055, top), (0.0, top)], segments: 20, material: MaterialKey(stringLiteral: white)))
        K.box(&m, V3(0, top + 0.14, 0), V3(0.3, 0.26, 0.9), white, bevel: 0.04)
        let nose = Float(0.5)
        m.add(Prim.cylinder(radius: 0.12, height: 0.18, bevel: 0.02, segments: 20, material: MaterialKey(stringLiteral: white)),
              Xform(translation: V3(0, top + 0.14, nose), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
        let blade = [V2(-0.02, 0.1), V2(-0.07, 0.35), V2(-0.12, 0.9), V2(-0.08, 1.52), V2(0.0, 1.6), V2(0.04, 1.5), V2(0.06, 0.9), V2(0.03, 0.35)]
        for k in 0..<3 {
            let q = simd_quatf(degrees: rotorAngle + Float(k) * 120, axis: V3(0, 0, 1))
            m.add(Prim.extrude(blade, depth: 0.022, bevel: 0.006, material: "plastic.gloss"), Xform(translation: V3(0, top + 0.14, nose + 0.12), rotation: q))
        }
        m.add(Prim.cylinder(radius: 0.015, height: 1.1, bevel: 0.003, segments: 8, material: "metal.steel"),
              Xform(translation: V3(0, top + 0.18, -0.35), rotation: simd_quatf(degrees: -90, axis: V3(1, 0, 0))))
        K.box(&m, V3(0, top + 0.22, -1.2), V3(0.025, 0.55, 0.7), SK.paint(0xC8102E), bevel: 0.006)
        return K.finish(&m, ao: 0.05)
    }
}
