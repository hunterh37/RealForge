import simd
import Foundation

/// Construction site cabin, 6.0 x 2.4 x 2.6 m: steel portable office on skids with door, two windows and roof ribs.
public struct SiteCabin: RealAsset {
    public static let id = "site-cabin"
    public static let summary = "Construction site cabin, 6 x 2.4 m: ribbed steel portable office on skids with steps, door and two windows."
    public static let tags = ["prop", "construction", "building", "metal"]
    public static let budget = 5900
    public static let author = "hunterh37"

    /// Cabin length in meters.
    public var length: Float = 6.0
    /// Body color, sRGB hex.
    public var bodyColor: UInt32 = 0x4B6B88
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let L = length, W: Float = 2.4, H: Float = 2.6
        let body = MaterialKey(stringLiteral: "metal.painted:" + String(bodyColor, radix: 16, uppercase: true))
        for z: Float in [-0.9, 0.9] { bx(&m, V3(L, 0.12, 0.12), V3(0, 0.06, z), "metal.galvanized-aged", r: 0.01) }
        bx(&m, V3(L, H - 0.2, W), V3(0, 0.2 + (H - 0.2) / 2, 0), body, r: 0.02, bs: 2)
        bx(&m, V3(L + 0.1, 0.08, W + 0.1), V3(0, H + 0.04, 0), "metal.galvanized", r: 0.01, bs: 2)
        var x = -L / 2 + 0.3
        while x < L / 2 - 0.2 { bx(&m, V3(0.02, 0.012, W - 0.1), V3(x, H + 0.09, 0), "metal.galvanized", r: 0.003); x += 0.4 }
        x = -L / 2 + 0.2
        while x < L / 2 - 0.1 { bx(&m, V3(0.04, H - 0.5, 0.012), V3(x, 1.4, W / 2 + 0.006), "metal.galvanized-aged", r: 0.004); x += 0.5 }
        bx(&m, V3(0.9, 2.0, 0.05), V3(-L / 2 + 0.8, 1.22, W / 2 + 0.02), "metal.painted:E8E8E4", r: 0.01, bs: 2)
        bx(&m, V3(0.05, 0.12, 0.04), V3(-L / 2 + 1.1, 1.2, W / 2 + 0.06), "metal.steel", r: 0.008)
        for wx: Float in [-0.4, 1.5] {
            bx(&m, V3(1.1, 0.9, 0.04), V3(wx, 1.55, W / 2 + 0.02), "metal.aluminum-brushed", r: 0.008)
            bx(&m, V3(0.98, 0.78, 0.045), V3(wx, 1.55, W / 2 + 0.025), "glass.clear", r: 0.004)
            bx(&m, V3(0.02, 0.78, 0.05), V3(wx, 1.55, W / 2 + 0.03), "metal.aluminum-brushed", r: 0.003)
        }
        bx(&m, V3(1.1, 0.06, 0.7), V3(-L / 2 + 0.8, 0.14, W / 2 + 0.4), "metal.galvanized", r: 0.006)
        bx(&m, V3(1.1, 0.06, 0.4), V3(-L / 2 + 0.8, 0.0, W / 2 + 0.2 + 0.4), "metal.galvanized", r: 0.006)
        return K.finish(&m, ao: 0.3)
    }
}
