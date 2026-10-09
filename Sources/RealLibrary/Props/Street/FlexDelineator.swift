import simd
import Foundation

public struct FlexDelineator: RealAsset {
    public static let id = "flex-delineator"
    public static let summary = "Flexible traffic delineator post, 1.0 m, white poly with orange reflective bands on a rubber base."
    public static let tags = ["prop", "road", "barrier", "construction", "plastic"]
    public static let budget = 2500
    public init() {}
    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)

        cy(&m, 0.15, 0.04, V3(0,0,0), "plastic.black", bevel: 0.01)
        m.add(turned([(0,0.04),(0.05,0.04),(0.035,0.2),(0.03,1.0),(0,1.0)], segments: 24, material: "plastic.white", seamTile: 0.3))
        for y: Float in [0.55,0.8] { cy(&m, 0.032, 0.1, V3(0,y,0), "plastic.orange", bevel: 0.001) }
        groundAO(&m, height: 0.2, floor: 0.6)
        return LODModel(m)
    }
}
