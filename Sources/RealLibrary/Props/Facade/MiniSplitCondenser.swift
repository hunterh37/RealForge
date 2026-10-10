import simd
import Foundation

/// Mini-split condenser 0.8 x 0.6 x 0.35 m: painted steel cabinet, round fan grille, service valves and wall bracket.
public struct MiniSplitCondenser: RealAsset {
    public static let id = "mini-split-condenser"
    public static let summary = "Mini-split condenser 0.8 x 0.6 x 0.35 m: painted steel cabinet, round fan grille, service valves and wall bracket."
    public static let tags = ["prop", "facade", "building", "appliance", "metal"]
    public static let budget = 3400
    public static let author = "hunterh37"

    /// Primary material key.
    public var material: String = "metal.painted:E8E8E4"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let material = self.material
        let w: Float = 0.8, h: Float = 0.6, d: Float = 0.35
        K.box(&m, V3(0, h / 2 + 0.04, 0), V3(w, h, d), material, bevel: 0.01)
        let fz = d / 2 + 0.004, fy = h / 2 + 0.06
        K.box(&m, V3(0, fy, d / 2 - 0.005), V3(0.44, 0.44, 0.012), "metal.painted:C9CCCE", bevel: 0.006)
        for r: Float in [0.07, 0.12, 0.17, 0.21] { m.add(Prim.torus(major: r, minor: 0.003, segments: 28, sides: 6, material: "metal.painted:3A3D40"), Xform(translation: V3(0, fy, fz + 0.005), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0)))) }
        for a: Float in [0, 45, 90, 135] { K.box(&m, V3(0, fy, fz + 0.005), V3(0.44, 0.004, 0.004), "metal.painted:3A3D40", bevel: 0.001, rot: simd_quatf(degrees: a, axis: V3(0, 0, 1))) }
        m.add(Prim.cylinder(radius: 0.03, height: 0.02, bevel: 0.004, segments: 16, material: "plastic.black"), Xform(translation: V3(0, fy, fz), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
        for sx: Float in [-1, 1] { K.box(&m, V3(sx * (w / 2 - 0.1), 0.02, 0), V3(0.05, 0.04, d - 0.06), "metal.galvanized", bevel: 0.004) }
        for sx: Float in [-1, 1] { cy(&m, 0.012, 0.04, V3(sx * 0.03 + w / 2 - 0.1, 0.1, -d / 2 - 0.0), "metal.copper", bevel: 0.002, seg: 12) }
        return K.finish(&m, ao: 0.05)
    }
}
