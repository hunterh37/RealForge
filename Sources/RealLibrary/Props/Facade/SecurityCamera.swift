import simd
import Foundation

/// Bullet security camera 0.3 m: cylindrical housing with sun shield, glass lens ring, wall mount and cable gland.
public struct SecurityCamera: RealAsset {
    public static let id = "security-camera"
    public static let summary = "Bullet security camera 0.3 m: cylindrical housing with sun shield, glass lens ring, wall mount and cable gland."
    public static let tags = ["prop", "facade", "building", "electronics"]
    public static let budget = 1800
    public static let author = "hunterh37"

    /// Primary material key.
    public var material: String = "plastic.white"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let material = self.material
        K.box(&m, V3(0, 0.1, -0.1), V3(0.06, 0.1, 0.02), "metal.painted:C9CCCE", bevel: 0.004)
        rod(&m, V3(0, 0.1, -0.09), V3(0, 0.1, -0.02), 0.012, "metal.painted:C9CCCE", sides: 8)
        m.add(Prim.cylinder(radius: 0.035, height: 0.22, bevel: 0.004, segments: 20, material: material), Xform(translation: V3(0, 0.12, -0.02), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
        K.box(&m, V3(0, 0.162, 0.07), V3(0.08, 0.004, 0.2), material, bevel: 0.002)
        m.add(Prim.cylinder(radius: 0.028, height: 0.006, bevel: 0.001, segments: 20, material: "glass.tinted"), Xform(translation: V3(0, 0.12, 0.2), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
        for a in 0..<6 { let t = Float(a) * .pi / 3; cy(&m, 0.003, 0.004, V3(cos(t) * 0.022, 0.12 + sin(t) * 0.022 - 0.0, 0.2), "emissive.indicator", bevel: 0.001, seg: 6) }
        return K.finish(&m, ao: 0.05)
    }
}
