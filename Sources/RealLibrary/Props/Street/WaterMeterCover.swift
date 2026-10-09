import simd
import Foundation

public struct WaterMeterCover: RealAsset {
    public static let id = "water-meter-cover"
    public static let summary = "Cast-iron utility meter cover, 0.3 m disc in a concrete collar with pick hole and lettering ring."
    public static let tags = ["prop", "urban", "street", "metal", "road"]
    public static let budget = 3000
    public init() {}
    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)

        cy(&m, 0.22, 0.02, V3(0,0,0), "concrete.smooth", bevel: 0.004)
        cy(&m, 0.15, 0.03, V3(0,0,0), "metal.cast-iron-street", bevel: 0.003, seg: 48)
        m.add(Prim.torus(major: 0.1, minor: 0.004, material: "metal.cast-iron-street"), Xform(translation: V3(0,0.032,0)))
        cy(&m, 0.015, 0.035, V3(0.06,0,0), "metal.rust")
        groundAO(&m, height: 0.2, floor: 0.6)
        return LODModel(m)
    }
}
