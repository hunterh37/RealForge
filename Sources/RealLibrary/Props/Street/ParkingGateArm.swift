import simd
import Foundation

public struct ParkingGateArm: RealAsset {
    public static let id = "parking-gate-arm"
    public static let summary = "Parking barrier gate: steel housing, striped boom arm and tip support post."
    public static let tags = ["prop", "road", "barrier", "metal"]
    public static let budget = 8000
    public init() {}
    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)

        bx(&m, V3(0.3,1.0,0.3), V3(-1.4,0.5,0), "metal.painted:EFEFEF", r: 0.02)
        bx(&m, V3(0.18,0.2,0.01), V3(-1.4,0.75,0.155), "plastic.black")
        for i in 0..<8 { bx(&m, V3(0.25,0.08,0.06), V3(-1.05+Float(i)*0.3,0.95,0), i % 2 == 0 ? "plastic.white" : "plastic.orange", r: 0.01) }
        bx(&m, V3(0.1,0.7,0.1), V3(1.4,0.35,0), "metal.galvanized")
        groundAO(&m, height: 0.2, floor: 0.6)
        return LODModel(m)
    }
}
