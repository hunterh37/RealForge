import simd
import Foundation

public struct LawnMower: RealAsset {
    public static let id = "lawn-mower"
    public static let summary = "Push lawn mower, 1.1 x 0.55 x 1.0 m: red steel deck, 21 in cut, black wheels, bag and folding handle."
    public static let tags = ["prop", "landscaping", "outdoor", "tool", "metal"]
    public static let budget = 9000
    public static let author = "realityhd"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let red = "metal.painted:C8321E", bk = "plastic.black"
        m.add(Prim.superellipsoid(V3(0.55, 0.14, 0.62), exponent: 4, subdivisions: 5, material: red), Xform(translation: V3(0, 0.17, 0)))
        m.add(Prim.cylinder(radius: 0.1, height: 0.1, bevel: 0.01, segments: 18, material: bk), Xform(translation: V3(0, 0.24, 0.05)))
        for x: Float in [-0.29, 0.29] {
            for z: Float in [-0.22, 0.24] {
                let r: Float = z < 0 ? 0.1 : 0.075
                m.add(Prim.cylinder(radius: r, height: 0.05, bevel: 0.008, segments: 20, material: "rubber.tire"), Xform(translation: V3(x, r, z), rotation: simd_quatf(degrees: 90, axis: V3(0, 0, 1))))
            }
        }
        K.rod(&m, [V3(-0.22, 0.2, -0.3), V3(-0.22, 0.6, -0.55), V3(-0.22, 0.95, -0.65), V3(0.22, 0.95, -0.65), V3(0.22, 0.6, -0.55), V3(0.22, 0.2, -0.3)], r: 0.012, "metal.steel", sides: 8)
        K.rod(&m, [V3(-0.2, 0.95, -0.65), V3(0.2, 0.95, -0.65)], r: 0.016, bk, sides: 8)
        K.box(&m, V3(0, 0.45, -0.52), V3(0.45, 0.35, 0.22), "fabric.nylon", bevel: 0.02)
        return K.finish(&m)
    }
}
