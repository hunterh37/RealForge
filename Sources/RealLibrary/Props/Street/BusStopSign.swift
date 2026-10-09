import simd
import Foundation

public struct BusStopSign: RealAsset {
    public static let id = "bus-stop-sign"
    public static let summary = "Bus stop sign: galvanized round pole, blue plate with route panel, concrete footing."
    public static let tags = ["prop", "urban", "street", "sign", "metal"]
    public static let budget = 3500
    public init() {}
    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)

        cy(&m, 0.04, 2.9, V3(0,0,0), "metal.galvanized")
        bx(&m, V3(0.4,0.5,0.01), V3(0,2.5,0.05), "metal.painted:1E4F9C", r: 0.01)
        bx(&m, V3(0.3,0.1,0.005), V3(0,2.6,0.06), "plastic.white"); bx(&m, V3(0.3,0.2,0.005), V3(0,2.4,0.06), "plastic.white")
        cy(&m, 0.12, 0.05, V3(0,0,0), "concrete.sidewalk")
        groundAO(&m, height: 0.2, floor: 0.6)
        return LODModel(m)
    }
}
