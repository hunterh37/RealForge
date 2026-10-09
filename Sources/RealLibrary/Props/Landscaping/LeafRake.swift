import simd
import Foundation

public struct LeafRake: RealAsset {
    public static let id = "leaf-rake"
    public static let summary = "Fan leaf rake, 1.6 m: bamboo-colored shaft, 22 steel tines fanning to 0.55 m with cross brace."
    public static let tags = ["prop", "landscaping", "garden", "outdoor", "tool", "handheld", "metal"]
    public static let budget = 5000
    public static let author = "realityhd"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let st = "metal.galvanized", sh = "wood.lumber-maple"
        K.rod(&m, [V3(0, 0.45, 0.0), V3(0, 1.6, 0)], r: 0.013, sh, sides: 10)
        let n = 22
        for i in 0..<n {
            let t = Float(i) / Float(n - 1) * 2 - 1
            K.rod(&m, [V3(0, 0.45, 0), V3(t * 0.12, 0.3, 0), V3(t * 0.275, 0.0, 0.0)], r: 0.0015, st, sides: 4)
        }
        K.rod(&m, K.arc(V3(0, -0.2, 0), 0.5, 55, 125, n: 12).map { V3($0.x, $0.y + 0.0, 0) }.map { V3($0.x, $0.y * 0.4 + 0.16, 0) }, r: 0.003, st, sides: 6)
        return K.finish(&m)
    }
}
