import simd
import Foundation

/// Horizontal brise-soleil 1.8 m: five tilted aluminum blades between end plates on wall brackets.
public struct BriseSoleil: RealAsset {
    public static let id = "brise-soleil"
    public static let summary = "Horizontal brise-soleil 1.8 m: five tilted aluminum blades between end plates on wall brackets."
    public static let tags = ["prop", "facade", "architecture", "metal"]
    public static let budget = 2600
    public static let author = "hunterh37"

    /// Primary material key.
    public var material: String = "metal.anodized"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let material = self.material
        let w: Float = 1.8, d: Float = 0.5
        for i in 0..<5 {
            let z = -d / 2 + 0.05 + (d - 0.1) * Float(i) / 4
            K.box(&m, V3(0, 0.15, z), V3(w - 0.04, 0.012, 0.1), material, bevel: 0.003, rot: simd_quatf(degrees: -28, axis: V3(1, 0, 0)))
        }
        for sx: Float in [-1, 1] {
            K.box(&m, V3(sx * (w / 2 - 0.01), 0.15, 0), V3(0.02, 0.28, d), "metal.painted:3A3D40", bevel: 0.004)
            K.box(&m, V3(sx * (w / 2 - 0.1), 0.15, -d / 2 + 0.01), V3(0.05, 0.3, 0.02), "metal.painted:3A3D40", bevel: 0.004)
        }
        return K.finish(&m, ao: 0.05)
    }
}
