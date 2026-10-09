import simd
import Foundation

public struct GardenHoseCoil: RealAsset {
    public static let id = "garden-hose-coil"
    public static let summary = "Coiled garden hose, 0.4 m diameter: 15 m green rubber hose in 7 loops with brass coupling."
    public static let tags = ["prop", "landscaping", "garden", "outdoor"]
    public static let budget = 5000
    public static let author = "realityhd"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        for i in 0..<7 {
            let y = 0.0095 + Float(i) * 0.019
            m.add(Prim.torus(major: 0.18 + Float(i % 2) * 0.002, minor: 0.0095, segments: 40, sides: 8, material: "rubber.tire"), Xform(translation: V3(0, y, 0)))
        }
        m.add(Prim.cylinder(radius: 0.014, height: 0.05, bevel: 0.002, segments: 12, material: "metal.brass"), Xform(translation: V3(0.16, 0.14, 0.09), rotation: simd_quatf(degrees: 90, axis: V3(0, 0, 1))))
        return K.finish(&m)
    }
}
