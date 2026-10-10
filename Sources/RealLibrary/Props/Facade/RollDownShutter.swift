import simd
import Foundation

/// Roll-down security shutter 1.5 x 2.2 m: interlocked aluminum slats, side guide rails, roller housing and bottom bar.
public struct RollDownShutter: RealAsset {
    public static let id = "roll-down-shutter"
    public static let summary = "Roll-down security shutter 1.5 x 2.2 m: interlocked aluminum slats, side guide rails, roller housing and bottom bar."
    public static let tags = ["prop", "facade", "window", "metal", "building"]
    public static let budget = 7000
    public static let author = "hunterh37"

    /// Primary material key.
    public var material: String = "metal.aluminum-brushed"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let material = self.material
        let w: Float = 1.5, h: Float = 2.2, d: Float = 0.2
        K.box(&m, V3(0, h - 0.09, 0), V3(w, 0.18, d), "metal.painted:C9CCCE", bevel: 0.01)
        for sx: Float in [-1, 1] { K.box(&m, V3(sx * (w / 2 - 0.025), (h - 0.18) / 2, 0), V3(0.05, h - 0.18, 0.05), "metal.painted:C9CCCE", bevel: 0.004) }
        let n = 40, top = h - 0.2, bot: Float = 0.1
        for i in 0..<n {
            let y = bot + (top - bot) * Float(i) / Float(n - 1)
            K.box(&m, V3(0, y, 0), V3(w - 0.1, (top - bot) / Float(n) * 0.95, 0.016), material, bevel: 0.002)
        }
        K.box(&m, V3(0, 0.04, 0), V3(w - 0.06, 0.08, 0.04), "metal.painted:3A3D40", bevel: 0.006)
        K.box(&m, V3(0, 0.04, 0.022), V3(0.12, 0.03, 0.01), "metal.steel", bevel: 0.002)
        return K.finish(&m, ao: 0.05)
    }
}
