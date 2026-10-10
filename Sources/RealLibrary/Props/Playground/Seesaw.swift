import simd
import Foundation

/// Playground seesaw, 2.4 m plank: steel fulcrum frame, laminated plank, bar handles, rubber stop pads.
public struct Seesaw: RealAsset {
    public static let id = "seesaw"
    public static let summary = "Playground seesaw, 2.4 m: steel fulcrum frame, laminated plank tilted 10 degrees, bar handles and tire pads."
    public static let tags = ["prop", "playground", "park", "outdoor", "wood"]
    public static let budget = 1600
    public static let author = "hunterh37"

    /// Plank tilt in degrees.
    public var tilt: Float = 10
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let frame: MaterialKey = "metal.painted:C0392B", pivot: Float = 0.45
        for z: Float in [-0.14, 0.14] {
            rod(&m, V3(-0.3, 0, z), V3(0, pivot, z), 0.025, frame, sides: 10)
            rod(&m, V3(0.3, 0, z), V3(0, pivot, z), 0.025, frame, sides: 10)
        }
        rod(&m, V3(0, pivot, -0.16), V3(0, pivot, 0.16), 0.03, "metal.steel", sides: 12)
        let rot = simd_quatf(degrees: tilt, axis: V3(0, 0, 1))
        m.add(plank(2.4, 0.26, 0.05, bevel: 0.012, material: "wood.painted-exterior"), Xform(translation: V3(0, pivot + 0.07, 0), rotation: rot))
        for s: Float in [-1, 1] {
            let p = rot.act(V3(s * 0.75, 0.08, 0)) + V3(0, pivot, 0)
            for z: Float in [-0.11, 0.11] { rod(&m, p + V3(0, 0.02, z), p + V3(0, 0.4, z), 0.012, "metal.steel", sides: 8) }
            rod(&m, p + V3(0, 0.4, -0.11), p + V3(0, 0.4, 0.11), 0.014, "metal.steel", sides: 8)
            m.add(Prim.cylinder(radius: 0.12, height: 0.14, bevel: 0.01, segments: 20, material: "rubber.tire"), Xform(translation: V3(s * 1.15, 0, 0)))
        }
        return K.finish(&m, ao: 0.2)
    }
}
