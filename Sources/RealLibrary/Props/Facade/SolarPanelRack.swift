import simd
import Foundation

/// Roofline solar rack 2.0 x 0.9 m: two tilted framed modules on aluminum A-frames with ballast blocks.
public struct SolarPanelRack: RealAsset {
    public static let id = "solar-panel-rack"
    public static let summary = "Roofline solar rack 2.0 x 0.9 m: two tilted framed modules on aluminum A-frames with ballast blocks."
    public static let tags = ["prop", "facade", "roof", "glass", "metal"]
    public static let budget = 3600
    public static let author = "hunterh37"

    /// Primary material key.
    public var material: String = "glass.tinted"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let material = self.material
        let pw: Float = 0.98, pl: Float = 0.9, tilt: Float = 25
        let rot = simd_quatf(degrees: -tilt, axis: V3(1, 0, 0)), mid = V3(0, 0.3 + pl / 2 * sin(tilt * .pi / 180), 0)
        for i in 0..<2 {
            let x = (Float(i) - 0.5) * (pw + 0.04)
            K.box(&m, mid + V3(x, 0, 0), V3(pw, 0.035, pl), "metal.anodized", bevel: 0.005, rot: rot)
            K.box(&m, mid + V3(x, 0, 0) + rot.act(V3(0, 0.019, 0)), V3(pw - 0.05, 0.004, pl - 0.05), material, bevel: 0.001, rot: rot)
            for c in 1..<4 { K.box(&m, mid + V3(x, 0, 0) + rot.act(V3(0, 0.022, -pl / 2 + pl * Float(c) / 4)), V3(pw - 0.05, 0.002, 0.004), "metal.aluminum-brushed", bevel: 0.001, rot: rot) }
        }
        for x: Float in [-0.9, 0.0, 0.9] {
            rod(&m, V3(x, 0.02, -0.4), V3(x, 0.02, 0.4), 0.014, "metal.aluminum-brushed", sides: 8)
            rod(&m, V3(x, 0.02, -0.4), V3(x, mid.y + 0.38 * sin(tilt * .pi / 180) + 0.0, -0.4 * cos(tilt * .pi / 180) * 0.9), 0.012, "metal.aluminum-brushed", sides: 8)
            rod(&m, V3(x, 0.02, 0.4), V3(x, 0.3 + 0.0, 0.4 * cos(tilt * .pi / 180)), 0.012, "metal.aluminum-brushed", sides: 8)
        }
        for x: Float in [-0.9, 0.9] { K.box(&m, V3(x, 0.05, 0.0), V3(0.2, 0.08, 0.4), "concrete.rough", bevel: 0.006) }
        return K.finish(&m, ao: 0.05)
    }
}
