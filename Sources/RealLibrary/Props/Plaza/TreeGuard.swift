import simd
import Foundation

/// Street tree guard, 0.9 m across and 1.2 m tall: eight steel stakes bound by three flat hoops on a ground ring.
public struct TreeGuard: RealAsset {
    public static let id = "tree-guard"
    public static let summary = "Street tree guard, 1.2 m tall: eight powder-coated steel stakes, three flat hoops and a ground ring."
    public static let tags = ["prop", "urban", "street", "barrier", "metal"]
    public static let budget = 5100
    public static let author = "hunterh37"

    /// Cage diameter in meters.
    public var diameter: Float = 0.9
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let r = diameter / 2, mat: MaterialKey = "metal.powdercoat"
        for i in 0..<8 {
            let a = Float(i) / 8 * .pi * 2
            rod(&m, V3(cos(a) * r, 0, sin(a) * r), V3(cos(a) * r, 1.2, sin(a) * r), 0.012, mat, sides: 8)
            m.add(Prim.cylinder(radius: 0.02, height: 0.02, bevel: 0.004, segments: 12, material: mat), Xform(translation: V3(cos(a) * r, 1.2, sin(a) * r)))
        }
        for y: Float in [0.04, 0.55, 1.15] {
            m.add(Prim.torus(major: r, minor: 0.012, segments: 48, sides: 8, material: mat), Xform(translation: V3(0, y, 0)))
        }
        return K.finish(&m, ao: 0.15)
    }
}
