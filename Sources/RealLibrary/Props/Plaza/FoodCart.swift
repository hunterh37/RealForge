import simd
import Foundation

/// Two-wheel street food cart, 1.5 m body: painted steel box, serving hatch, striped umbrella, push handle.
public struct FoodCart: RealAsset {
    public static let id = "food-cart"
    public static let summary = "Two-wheel street food cart, 1.5 m body: painted steel box, serving counter, rubber wheels, umbrella."
    public static let tags = ["prop", "urban", "street", "metal"]
    public static let budget = 2700
    public static let author = "hunterh37"

    /// Body paint, sRGB hex.
    public var bodyColor: UInt32 = 0xB8453A
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let paint = MaterialKey(stringLiteral: "metal.painted:" + String(bodyColor, radix: 16, uppercase: true))
        bx(&m, V3(1.5, 0.75, 0.9), V3(0, 0.85, 0), paint, r: 0.02, bs: 2)
        bx(&m, V3(1.56, 0.04, 0.96), V3(0, 1.24, 0), "metal.stainless", r: 0.01)
        bx(&m, V3(1.2, 0.34, 0.02), V3(0, 0.95, 0.455), "glass.pane", r: 0.004)
        bx(&m, V3(1.1, 0.04, 0.3), V3(0, 1.05, 0.62), "metal.stainless", r: 0.01)
        for x: Float in [-0.7, 0.7] { bx(&m, V3(0.06, 0.5, 0.06), V3(x, 0.47, 0.35), "metal.steel", r: 0.006) }
        bx(&m, V3(1.4, 0.05, 0.8), V3(0, 0.45, 0), "metal.steel", r: 0.006)
        for z: Float in [-0.53, 0.53] {
            m.add(Prim.cylinder(radius: 0.3, height: 0.08, bevel: 0.02, segments: 28, material: "rubber.tire"),
                  Xform(translation: V3(-0.1, 0.3, z - 0.04 * (z > 0 ? -1 : 1)), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
            rod(&m, V3(-0.1, 0.3, z * 0.55), V3(-0.1, 0.3, z * 1.0), 0.02, "metal.steel")
        }
        rod(&m, V3(0.75, 0.55, -0.3), V3(1.25, 0.85, -0.3), 0.02, "metal.steel")
        rod(&m, V3(0.75, 0.55, 0.3), V3(1.25, 0.85, 0.3), 0.02, "metal.steel")
        rod(&m, V3(1.25, 0.85, -0.38), V3(1.25, 0.85, 0.38), 0.022, "rubber.tire")
        rod(&m, V3(-0.55, 1.26, -0.4), V3(-0.55, 2.35, -0.4), 0.018, "metal.steel", sides: 8)
        m.add(turned([(0, 0.34), (0.5, 0.1), (1.05, 0), (1.05, -0.02), (0, -0.02)], segments: 8, material: "fabric.canvas"),
              Xform(translation: V3(-0.55, 2.3, -0.4), rotation: simd_quatf(degrees: rng.float(-4...4), axis: V3(0, 0, 1))))
        return K.finish(&m, ao: 0.25)
    }
}
