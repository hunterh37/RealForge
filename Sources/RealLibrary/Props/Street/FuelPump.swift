import simd
import Foundation

public struct FuelPump: RealAsset {
    public static let id = "fuel-pump"
    public static let summary = "Gas station pump, 1.5 m: red-painted cabinet, display head, hose with nozzle holster and island base."
    public static let tags = ["prop", "urban", "street", "metal", "industrial"]
    public static let budget = 6000
    public init() {}
    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)

        bx(&m, V3(0.9,0.15,0.5), V3(0,0.075,0), "concrete.smooth", r: 0.01)
        bx(&m, V3(0.5,1.1,0.3), V3(0,0.7,0), "metal.painted:B3201C", r: 0.02)
        bx(&m, V3(0.54,0.35,0.34), V3(0,1.42,0), "metal.painted:EFEFEF", r: 0.02)
        bx(&m, V3(0.3,0.12,0.01), V3(0,1.45,0.175), "plastic.black"); bx(&m, V3(0.2,0.08,0.01), V3(0,1.25,0.155), "plastic.black")
        m.add(Prim.tube([V3(0.25,0.9,0.1),V3(0.38,0.7,0.2),V3(0.3,0.4,0.25),V3(0.1,0.6,0.2)], radii: [0.018,0.018,0.018,0.018], sides: 8, seamTile: 0.2, material: "plastic.black", capEnd: true))
        bx(&m, V3(0.06,0.18,0.04), V3(-0.28,1.0,0.1), "metal.steel")
        groundAO(&m, height: 0.2, floor: 0.6)
        return LODModel(m)
    }
}
