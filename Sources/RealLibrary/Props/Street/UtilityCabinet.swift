import simd
import Foundation

public struct UtilityCabinet: RealAsset {
    public static let id = "utility-cabinet"
    public static let summary = "Green steel utility cabinet, 1.2 m, double door with louvers, stainless handle and concrete pad."
    public static let tags = ["prop", "urban", "street", "metal", "industrial"]
    public static let budget = 6500
    public init() {}
    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)

        let g: MaterialKey = "metal.painted:3A5A40"
        bx(&m, V3(1.0,0.08,0.55), V3(0,0.04,0), "concrete.sidewalk", r: 0.01)
        bx(&m, V3(0.9,1.1,0.45), V3(0,0.65,0), g, r: 0.01)
        bx(&m, V3(0.94,0.04,0.5), V3(0,1.22,0), g, r: 0.008)
        bx(&m, V3(0.008,1.0,0.01), V3(0,0.65,0.226), "metal.painted:2A3F2E")
        for s: Float in [-1,1] { bx(&m, V3(0.02,0.2,0.03), V3(s*0.06,0.65,0.24), "metal.stainless") }
        for i in 0..<6 { bx(&m, V3(0.3,0.012,0.02), V3(-0.2,0.15+Float(i)*0.03,0.226), "metal.painted:2A3F2E") }
        groundAO(&m, height: 0.2, floor: 0.6)
        return LODModel(m)
    }
}
