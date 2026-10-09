import simd
import Foundation

public struct VendingMachine: RealAsset {
    public static let id = "vending-machine"
    public static let summary = "Outdoor drink vending machine, 1.85 m, red cabinet, glass display, keypad and dispense flap."
    public static let tags = ["prop", "urban", "street", "metal", "glass"]
    public static let budget = 6500
    public init() {}
    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)

        bx(&m, V3(0.9,1.85,0.8), V3(0,0.925,0), "metal.painted:B3201C", r: 0.02)
        bx(&m, V3(0.6,1.2,0.01), V3(-0.1,1.1,0.405), "glass.clear")
        bx(&m, V3(0.18,0.5,0.02), V3(0.33,1.3,0.41), "metal.painted:2A2C30", r: 0.005)
        bx(&m, V3(0.12,0.04,0.01), V3(0.33,1.5,0.425), "plastic.black")
        bx(&m, V3(0.5,0.22,0.02), V3(-0.1,0.2,0.405), "plastic.black", r: 0.01)
        for i in 0..<5 { bx(&m, V3(0.56,0.01,0.3), V3(-0.1,0.65+Float(i)*0.23,0.2), "metal.stainless", r: 0.002) }
        groundAO(&m, height: 0.2, floor: 0.6)
        return LODModel(m)
    }
}
