import simd
import Foundation

public struct VentPipe: RealAsset {
    public static let id = "vent-pipe"
    public static let summary = "Roof plumbing vent stack, 0.5 m, PVC pipe with cap, lead-free flashing collar."
    public static let tags = ["prop", "urban", "industrial", "plastic"]
    public static let budget = 1500
    public init() {}
    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)

        cy(&m, 0.12, 0.02, V3(0,0,0), "metal.galvanized", seg: 24)
        cy(&m, 0.05, 0.6, V3(0,0.02,0), "plastic.white", seg: 24)
        cy(&m, 0.065, 0.04, V3(0,0.6,0), "plastic.white", seg: 24)
        groundAO(&m, height: 0.2, floor: 0.6)
        return LODModel(m)
    }
}
