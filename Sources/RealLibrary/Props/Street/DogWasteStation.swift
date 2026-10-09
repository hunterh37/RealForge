import simd
import Foundation

public struct DogWasteStation: RealAsset {
    public static let id = "dog-waste-station"
    public static let summary = "Pet waste station, 1.5 m: green post, bag dispenser box, lidded bin with pedal-free flap."
    public static let tags = ["prop", "park", "outdoor", "container", "metal"]
    public static let budget = 3500
    public init() {}
    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)

        cy(&m, 0.03, 1.5, V3(0,0,0), "metal.painted:2E5A38", seg: 16)
        bx(&m, V3(0.2,0.3,0.12), V3(0,1.2,0.03), "metal.painted:2E5A38", r: 0.01)
        bx(&m, V3(0.12,0.06,0.005), V3(0,1.2,0.093), "plastic.white")
        cy(&m, 0.12, 0.45, V3(0,0.3,0.06), "plastic.black", seg: 24)
        bx(&m, V3(0.2,0.08,0.02), V3(0,0.74,0.15), "metal.painted:2E5A38", r: 0.005)
        groundAO(&m, height: 0.2, floor: 0.6)
        return LODModel(m)
    }
}
