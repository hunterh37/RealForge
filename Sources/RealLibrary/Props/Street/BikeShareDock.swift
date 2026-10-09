import simd
import Foundation

public struct BikeShareDock: RealAsset {
    public static let id = "bike-share-dock"
    public static let summary = "Bike-share docking post, 1.0 m, aluminum column with screen, locking slot and rubber bumper."
    public static let tags = ["prop", "urban", "street", "metal"]
    public static let budget = 3500
    public init() {}
    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)

        bx(&m, V3(0.26,0.08,0.4), V3(0,0.04,0), "concrete.smooth", r: 0.01)
        bx(&m, V3(0.18,0.9,0.16), V3(0,0.5,0), "metal.aluminum-brushed", r: 0.02)
        bx(&m, V3(0.12,0.14,0.01), V3(0,0.82,0.085), "plastic.black", r: 0.004)
        bx(&m, V3(0.06,0.18,0.03), V3(0,0.45,0.095), "plastic.black", r: 0.01)
        bx(&m, V3(0.04,0.04,0.02), V3(0,0.56,0.09), "plastic.orange")
        groundAO(&m, height: 0.2, floor: 0.6)
        return LODModel(m)
    }
}
