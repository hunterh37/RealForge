import simd
import Foundation

public struct BenchPlanter: RealAsset {
    public static let id = "bench-planter"
    public static let summary = "Concrete bench planter, 2.0 m, raised bed with soil and a plank seat along one side."
    public static let tags = ["prop", "urban", "street", "concrete", "furniture"]
    public static let budget = 3500
    public init() {}
    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)

        bx(&m, V3(2.0,0.5,0.7), V3(0,0.25,0), "concrete.smooth", r: 0.015)
        bx(&m, V3(1.84,0.02,0.54), V3(0,0.49,0), "ground.mud", r: 0.002)
        for i in 0..<3 { bx(&m, V3(1.9,0.04,0.12), V3(0,0.55,0.28+Float(i)*0.0 - Float(i)*0.12 + 0.0 + 0.4 - 0.4), "wood.pine-aged") }
        groundAO(&m, height: 0.2, floor: 0.6)
        return LODModel(m)
    }
}
