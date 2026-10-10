import simd
import Foundation

/// Modular outdoor stage, 8 m wide, 6 m deep and 5.2 m tall: raised black deck with steps, aluminum truss frame, roof, backdrop, speaker stacks.
public struct OutdoorStage: RealAsset {
    public static let id = "outdoor-stage"
    public static let summary = "Outdoor stage, 8 x 6 m: raised deck with steps, aluminum truss portal, roof, black backdrop, speaker stacks, front lights."
    public static let tags = ["prop", "park", "urban", "outdoor", "metal"]
    public static let budget = 4700
    public static let author = "hunterh37"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let alu = "metal.aluminum-brushed", blk = "metal.painted:1C1C1E"
        K.box(&m, V3(0, 0.55, 0), V3(8, 1.1, 6), blk, bevel: 0.02)
        K.box(&m, V3(0, 1.12, 0), V3(8, 0.04, 6), "wood.weathered", bevel: 0.006)
        for i in 0..<4 { K.box(&m, V3(2.2, 0.14 + Float(i) * 0.28, 3.35 + Float(3 - i) * 0.0 + Float(3 - i) * 0.3), V3(1.6, 0.28, 0.3), "concrete.rough", bevel: 0.008) }
        for (x, z): (Float, Float) in [(-3.9, -2.9), (3.9, -2.9), (-3.9, 2.9), (3.9, 2.9)] {
            let b = V3(x, 1.12, z), t = V3(x, 5.0, z)
            for (dx, dz): (Float, Float) in [(-0.12, -0.12), (0.12, -0.12), (0.12, 0.12), (-0.12, 0.12)] {
                K.rod(&m, [b + V3(dx, 0, dz), t + V3(dx, 0, dz)], r: 0.025, alu, sides: 8)
            }
            var y: Float = 1.12
            while y < 4.9 {
                K.rod(&m, [V3(x - 0.12, y, z - 0.12), V3(x + 0.12, y + 0.4, z - 0.12)], r: 0.012, alu, sides: 5)
                K.rod(&m, [V3(x - 0.12, y, z + 0.12), V3(x + 0.12, y + 0.4, z + 0.12)], r: 0.012, alu, sides: 5)
                y += 0.4
            }
        }
        for z: Float in [-2.9, 2.9] { K.box(&m, V3(0, 5.0, z), V3(8, 0.35, 0.35), alu, bevel: 0.01) }
        K.box(&m, V3(0, 5.18, 0), V3(8.3, 0.06, 6.3), "plastic.matte:1C1C1E", bevel: 0.01)
        K.box(&m, V3(0, 3.1, -2.95), V3(7.7, 3.7, 0.04), "fabric.canvas", bevel: 0.004)
        for s: Float in [-1, 1] {
            K.box(&m, V3(s * 3.3, 2.1, 2.0), V3(0.8, 1.9, 0.7), "plastic.matte:151517", bevel: 0.02)
            for k in 0..<3 { K.box(&m, V3(s * 3.3, 1.6 + Float(k) * 0.55, 2.36), V3(0.62, 0.4, 0.02), "metal.steel", bevel: 0.004) }
        }
        for x in [-2.5, 0, 2.5] as [Float] { K.box(&m, V3(x, 4.7, 2.9), V3(0.3, 0.25, 0.3), "plastic.black", bevel: 0.02) }
        return K.finish(&m, ao: 0.3)
    }
}
