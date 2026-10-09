import simd
import Foundation

public struct PlanterPot: RealAsset {
    public static let id = "planter-pot"
    public static let summary = "Large terracotta street planter, 0.6 m, flared rim and tapered body with dirt fill."
    public static let tags = ["prop", "urban", "garden", "ceramic"]
    public static let budget = 3000
    public init() {}
    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)

        m.add(turned([(0,0),(0.17,0),(0.26,0.55),(0.3,0.6),(0.3,0.64),(0.25,0.64),(0.25,0.58),(0,0.58)], segments: 48, material: "concrete.rough", seamTile: 0.6))
        cy(&m, 0.25, 0.01, V3(0,0.52,0), "ground.mud", bevel: 0.001, seg: 48)
        groundAO(&m, height: 0.2, floor: 0.6)
        return LODModel(m)
    }
}
