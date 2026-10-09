import simd
import Foundation

public struct StoneBench: RealAsset {
    public static let id = "stone-bench"
    public static let summary = "Granite plaza bench, 1.8 m, polished slab seat on two cut block supports."
    public static let tags = ["prop", "urban", "park", "stone", "furniture"]
    public static let budget = 2000
    public init() {}
    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)

        let g: MaterialKey = "concrete.exposed-aggregate"
        bx(&m, V3(1.8,0.1,0.5), V3(0,0.45,0), g, r: 0.01)
        for s: Float in [-1,1] { bx(&m, V3(0.18,0.4,0.42), V3(s*0.7,0.2,0), g, r: 0.01) }
        groundAO(&m, height: 0.2, floor: 0.6)
        return LODModel(m)
    }
}
