import simd
import Foundation

/// Wall vent louver: an aluminum frame with seven angled blades over an insect screen, with a cast
/// flange and four screws. A dusty streak sits under the lowest blade.
public struct WallVentLouver: RealAsset {
    public static let id = "wall-vent-louver"
    public static let summary = "Wall vent louver, 0.45 m x 0.3 m: aluminum frame, angled blades, insect screen behind."
    public static let tags = ["prop", "architecture", "facade", "trim", "metal"]
    public static let budget = 5_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 25, elevation: 8, distance: 0.8)

    public var width: Float = 0.45
    public var height: Float = 0.3
    public var blades = 7
    public var tilt: Float = 38
    public var frame: MaterialKey = "metal.painted:C8C6BE"
    public var blade: MaterialKey = "metal.aluminum-brushed"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let W = width, H = height, f: Float = 0.026, d: Float = 0.04
        FA.box(&m, V3(W, f, d), V3(0, f / 2, d / 2), frame, r: 0.003)
        FA.box(&m, V3(W, f, d), V3(0, H - f / 2, d / 2), frame, r: 0.003)
        for e: Float in [-1, 1] { FA.box(&m, V3(f, H - 2 * f, d), V3(e * (W / 2 - f / 2), H / 2, d / 2), frame, r: 0.003) }
        FA.box(&m, V3(W - 2 * f, H - 2 * f, 0.002), V3(0, H / 2, 0.006), "glass.wire-mesh", r: 0.0005)
        let pitch = (H - 2 * f) / Float(blades)
        for i in 0..<blades {
            FA.box(&m, V3(W - 2 * f + 0.004, 0.007, 0.05), V3(0, f + pitch * (Float(i) + 0.5), 0.028), blade, r: 0.002, rot: FA.q(-tilt, FA.X))
        }
        for sx: Float in [-1, 1] { for sy: Float in [-1, 1] {
            hexBolt(&m, at: V3(sx * (W / 2 - f / 2), H / 2 + sy * (H / 2 - f / 2), d), normal: FA.Z, size: 0.008, material: "metal.steel")
        }}
        return LODModel(FA.centerZ(m))
    }
}
