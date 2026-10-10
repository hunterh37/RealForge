import simd
import Foundation

/// Projecting blade sign 0.6 m: wrought-iron scroll bracket, hanging painted panel and S-hooks.
public struct BladeSign: RealAsset {
    public static let id = "blade-sign"
    public static let summary = "Projecting blade sign 0.6 m: wrought-iron scroll bracket, hanging painted panel and S-hooks."
    public static let tags = ["prop", "facade", "sign", "metal"]
    public static let budget = 3000
    public static let author = "hunterh37"

    /// Primary material key.
    public var material: String = "sign.white"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let material = self.material
        let d: Float = 0.9, iron = "metal.painted:1E1E1E"
        K.box(&m, V3(0, 0.45, -d / 2 + 0.005), V3(0.1, 0.4, 0.01), iron, bevel: 0.003)
        rod(&m, V3(0, 0.62, -d / 2), V3(0, 0.62, d / 2 - 0.05), 0.012, iron, sides: 8)
        K.rod(&m, [V3(0, 0.62, d / 2 - 0.05), V3(0, 0.66, d / 2 - 0.02), V3(0, 0.68, d / 2 - 0.06)], r: 0.008, iron, sides: 6)
        let ay = V3(0, 0.0, 0.0)
        var pts: [V3] = []; for p in K.arc(ay, 0.18, 0, 90, n: 12) { pts.append(V3(0, 0.45 + p.y, -d / 2 + p.x)) }
        K.rod(&m, pts, r: 0.008, iron, sides: 6)
        let zc = d / 2 - 0.35
        K.box(&m, V3(0, 0.3, zc), V3(0.03, 0.36, 0.56), material, bevel: 0.004)
        K.box(&m, V3(0, 0.3, zc), V3(0.036, 0.3, 0.5), "sign.red", bevel: 0.003)
        for z: Float in [-0.2, 0.2] { rod(&m, V3(0, 0.62, zc + z), V3(0, 0.48, zc + z), 0.004, iron, sides: 6) }
        return K.finish(&m, ao: 0.05)
    }
}
