import simd
import Foundation

public struct CrosswalkPost: RealAsset {
    public static let id = "crosswalk-post"
    public static let summary = "Pedestrian push-button post, 1.1 m, yellow-powdercoat pole, aluminum button box with arrow plate."
    public static let tags = ["prop", "urban", "street", "metal", "road"]
    public static let budget = 2200
    public init() {}
    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)

        cy(&m, 0.04, 1.1, V3(0,0,0), "metal.signal-yellow", seg: 20)
        bx(&m, V3(0.12,0.2,0.08), V3(0,0.95,0.07), "metal.aluminum-brushed", r: 0.01)
        cy(&m, 0.025, 0.012, V3(0,0.95,0.11), "metal.stainless", seg: 20)
        bx(&m, V3(0.1,0.04,0.005), V3(0,1.04,0.112), "plastic.black")
        groundAO(&m, height: 0.2, floor: 0.6)
        return LODModel(m)
    }
}
