import simd
import Foundation

/// Horizontal ladder (monkey bars), 3.0 m long and 2.2 m high: two steel arch ends with ten rungs at 0.3 m spacing.
public struct MonkeyBars: RealAsset {
    public static let id = "monkey-bars"
    public static let summary = "Monkey bars, 3 m long and 2.2 m high: two steel arch ends, twin rails and ten round rungs."
    public static let tags = ["prop", "playground", "park", "outdoor", "metal"]
    public static let budget = 1200
    public static let author = "hunterh37"

    /// Rung count.
    public var rungs = 10
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let L: Float = 3.0, H: Float = 2.2, W: Float = 0.6, mat: MaterialKey = "metal.painted:2D6FB5"
        for x: Float in [-L / 2, L / 2] {
            for z: Float in [-W / 2, W / 2] { rod(&m, V3(x, 0, z * 1.5), V3(x, H, z), 0.035, mat, sides: 12) }
            bx(&m, V3(0.1, 0.012, 0.28), V3(x, 0.006, W * 0.75), "metal.galvanized", r: 0.003)
            bx(&m, V3(0.1, 0.012, 0.28), V3(x, 0.006, -W * 0.75), "metal.galvanized", r: 0.003)
        }
        for z: Float in [-W / 2, W / 2] { rod(&m, V3(-L / 2, H, z), V3(L / 2, H, z), 0.03, mat, sides: 12) }
        let n = max(2, rungs)
        for i in 0..<n {
            let x = -L / 2 + 0.15 + (L - 0.3) * Float(i) / Float(n - 1)
            rod(&m, V3(x, H, -W / 2), V3(x, H, W / 2), 0.016, "metal.galvanized", sides: 10)
        }
        return K.finish(&m, ao: 0.2)
    }
}
