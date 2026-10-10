import simd
import Foundation

/// Terracotta frieze panel 2.0 x 0.6 m: framed slab with a repeating palmette and rosette relief.
public struct TerracottaFriezePanel: RealAsset {
    public static let id = "terracotta-frieze-panel"
    public static let summary = "Terracotta frieze panel 2.0 x 0.6 m: framed slab with a repeating palmette and rosette relief."
    public static let tags = ["prop", "facade", "trim", "ornament", "ceramic"]
    public static let budget = 6300
    public static let author = "hunterh37"

    /// Primary material key.
    public var material: String = "ceramic.terracotta"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let material = self.material
        let w: Float = 2.0, h: Float = 0.6
        K.box(&m, V3(0, h / 2, 0), V3(w, h, 0.04), material, bevel: 0.004)
        K.box(&m, V3(0, 0.02, 0.025), V3(w, 0.04, 0.02), material, bevel: 0.003)
        K.box(&m, V3(0, h - 0.02, 0.025), V3(w, 0.04, 0.02), material, bevel: 0.003)
        let n = 8
        for i in 0..<n {
            let x = -w / 2 + w / Float(n) * (Float(i) + 0.5)
            m.add(Prim.cylinder(radius: 0.06, height: 0.02, bevel: 0.004, segments: 16, material: material), Xform(translation: V3(x, h / 2 - 0.12, 0.02), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
            K.box(&m, V3(x, h / 2 + 0.12, 0.03), V3(0.03, 0.14, 0.01), material, bevel: 0.002)
            K.box(&m, V3(x, h / 2 + 0.12, 0.03), V3(0.1, 0.025, 0.01), material, bevel: 0.002, rot: simd_quatf(degrees: 30, axis: V3(0, 0, 1)))
            K.box(&m, V3(x, h / 2 + 0.12, 0.03), V3(0.1, 0.025, 0.01), material, bevel: 0.002, rot: simd_quatf(degrees: -30, axis: V3(0, 0, 1)))
        }
        return K.finish(&m, ao: 0.05)
    }
}
