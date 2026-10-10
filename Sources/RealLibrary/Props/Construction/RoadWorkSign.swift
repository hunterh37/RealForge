import simd
import Foundation

/// Temporary "road work ahead" diamond sign on a folding stand, 1.25 m sign width, 1.6 m tall: orange face, black border and legend bars, steel legs.
public struct RoadWorkSign: RealAsset {
    public static let id = "road-work-sign"
    public static let summary = "Temporary road-work diamond sign, 1.6 m tall: orange reflective face, black border, folding steel tripod stand."
    public static let tags = ["prop", "road", "street", "construction", "sign", "metal"]
    public static let budget = 1200
    public static let author = "hunterh37"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let r: Float = 0.63, cy0: Float = 1.0, dia = Shape2D.polygon(sides: 4, radius: r)
        let rot = simd_quatf(degrees: 45, axis: V3(0, 0, 1))
        m.add(Prim.extrude(dia, depth: 0.012, bevel: 0.003, material: "plastic.orange"), Xform(translation: V3(0, cy0, 0), rotation: rot))
        let s: Float = r * 0.7071 * 2 - 0.1
        for k in 0..<4 {
            let ang = Float(k) * 90
            let dir = simd_quatf(degrees: ang, axis: V3(0, 0, 1)).act(V3(1, 0, 0))
            let mid = V3(0, cy0, 0.008) + dir * (r * 0.7071 - 0.05)
            let tang = simd_quatf(degrees: ang, axis: V3(0, 0, 1))
            K.box(&m, mid, V3(0.025, s, 0.006), "plastic.black", bevel: 0.002, rot: tang)
        }
        K.box(&m, V3(0, cy0, 0.008), V3(0.5, 0.05, 0.006), "plastic.black", bevel: 0.002)
        K.box(&m, V3(0, cy0 - 0.12, 0.008), V3(0.36, 0.04, 0.006), "plastic.black", bevel: 0.002)
        K.box(&m, V3(0, cy0 + 0.12, 0.008), V3(0.36, 0.04, 0.006), "plastic.black", bevel: 0.002)
        K.rod(&m, [V3(0, cy0 - r * 0.9, -0.01), V3(0, 0.32, -0.01)], r: 0.018, "metal.galvanized", sides: 8)
        K.rod(&m, [V3(0, 0.55, -0.02), V3(0, 0.05, 0.0)], r: 0.016, "metal.galvanized", sides: 8)
        let hub = V3(0, 0.62, -0.03)
        for (x, z): (Float, Float) in [(-0.5, 0.3), (0.5, 0.3), (0, -0.55)] {
            K.rod(&m, [hub, V3(x, 0.02, z)], r: 0.016, "metal.galvanized", sides: 8)
        }
        return K.finish(&m, ao: 0.1)
    }
}
