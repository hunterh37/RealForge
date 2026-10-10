import simd
import Foundation

/// Concrete parking wheel stop, 1.8 m long, 0.2 m wide and 0.1 m tall, chamfered, with two steel anchor pins.
public struct WheelStop: RealAsset {
    public static let id = "wheel-stop"
    public static let summary = "Concrete parking wheel stop, 1.8 m: chamfered precast block with two steel anchor pins."
    public static let tags = ["prop", "road", "street", "barrier", "concrete"]
    public static let budget = 600
    public static let author = "hunterh37"

    /// Block length in meters.
    public var length: Float = 1.8
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        m.add(Prim.extrude([V2(-0.1, 0), V2(0.1, 0), V2(0.085, 0.1), V2(-0.085, 0.1)], depth: length, bevel: 0.008, material: "concrete.rough"),
              Xform(rotation: simd_quatf(degrees: 0, axis: .up)))
        for z: Float in [-length / 2 + 0.22, length / 2 - 0.22] {
            m.add(Prim.cylinder(radius: 0.012, height: 0.02, bevel: 0.003, segments: 12, material: "metal.rust"), Xform(translation: V3(0, 0.1, z + rng.float(-0.01...0.01))))
        }
        return K.finish(&m, ao: 0.1)
    }
}
