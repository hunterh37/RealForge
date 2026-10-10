import simd
import Foundation

/// Vertical fin screen 1.6 x 2.4 m: nine angled anodized aluminum fins between top and bottom rails.
public struct VerticalFinScreen: RealAsset {
    public static let id = "vertical-fin-screen"
    public static let summary = "Vertical fin screen 1.6 x 2.4 m: nine angled anodized aluminum fins between top and bottom rails."
    public static let tags = ["prop", "facade", "architecture", "metal"]
    public static let budget = 3200
    public static let author = "hunterh37"

    /// Primary material key.
    public var material: String = "metal.anodized"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let material = self.material
        let w: Float = 1.6, h: Float = 2.4
        K.box(&m, V3(0, h - 0.025, 0), V3(w, 0.05, 0.12), "metal.painted:3A3D40", bevel: 0.004)
        K.box(&m, V3(0, 0.025, 0), V3(w, 0.05, 0.12), "metal.painted:3A3D40", bevel: 0.004)
        for i in 0..<9 {
            let x = -w / 2 + 0.1 + (w - 0.2) * Float(i) / 8
            K.box(&m, V3(x, h / 2, 0), V3(0.02, h - 0.1, 0.28), material, bevel: 0.003, rot: K.yaw(25))
        }
        return K.finish(&m, ao: 0.05)
    }
}
