import simd
import Foundation

public struct TrafficBarricade: RealAsset {
    public static let id = "traffic-barricade"
    public static let summary = "Type III road barricade, 1.8 m wide, three striped rails on A-frame legs."
    public static let tags = ["prop", "road", "barrier", "construction", "plastic"]
    public static let budget = 4500
    public init() {}
    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)

        for s: Float in [-1,1] { bx(&m, V3(0.05,1.2,0.05), V3(s*0.85,0.6,0.1), "metal.signal-yellow"); bx(&m, V3(0.05,1.2,0.05), V3(s*0.85,0.6,-0.1), "metal.signal-yellow", yaw: 0); bx(&m, V3(0.05,0.05,0.7), V3(s*0.85,0.05,0), "metal.galvanized") }
        for y: Float in [0.45,0.78,1.1] { for i in 0..<6 { bx(&m, V3(0.3,0.2,0.03), V3(-0.75+Float(i)*0.3,y,0), i % 2 == 0 ? "plastic.white" : "plastic.orange", r: 0.004) } }
        groundAO(&m, height: 0.2, floor: 0.6)
        return LODModel(m)
    }
}
