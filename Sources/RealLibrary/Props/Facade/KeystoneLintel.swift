import simd
import Foundation

/// Limestone window lintel 1.2 m with a tapered projecting keystone and shallow voussoir joints.
public struct KeystoneLintel: RealAsset {
    public static let id = "keystone-lintel"
    public static let summary = "Limestone window lintel 1.2 m with a tapered projecting keystone and shallow voussoir joints."
    public static let tags = ["prop", "facade", "trim", "ornament", "stone"]
    public static let budget = 1800
    public static let author = "hunterh37"

    /// Primary material key.
    public var material: String = "stone.limestone"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let material = self.material
        let w: Float = 1.2
        K.box(&m, V3(0, 0.12, 0), V3(w, 0.24, 0.1), material, bevel: 0.006)
        let keystone = Prim.extrude([V2(-0.07, 0.35), V2(0.07, 0.35), V2(0.05, 0), V2(-0.05, 0)], depth: 0.12, bevel: 0.006, bevelSegments: 2, material: material)
        m.add(keystone, Xform(translation: V3(0, 0, 0.01)))
        for x: Float in [-0.3, 0.3] { K.box(&m, V3(x, 0.12, 0.052), V3(0.004, 0.22, 0.004), "stone.limestone-sooted", bevel: 0.001) }
        K.box(&m, V3(0, 0.005, 0.0), V3(w, 0.01, 0.1), "stone.limestone-sooted", bevel: 0.002)
        return K.finish(&m, ao: 0.05)
    }
}
