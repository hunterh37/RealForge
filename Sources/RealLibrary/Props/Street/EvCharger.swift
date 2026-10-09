import simd
import Foundation

public struct EvCharger: RealAsset {
    public static let id = "ev-charger"
    public static let summary = "Curbside EV charger pedestal, 1.5 m: white shell, display, holstered coiled cable and connector."
    public static let tags = ["prop", "urban", "street", "metal", "plastic"]
    public static let budget = 6000
    public init() {}
    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)

        bx(&m, V3(0.3,1.4,0.2), V3(0,0.8,0), "plastic.white", r: 0.03)
        bx(&m, V3(0.34,0.1,0.24), V3(0,0.05,0), "metal.painted:2A2C30"); bx(&m, V3(0.22,0.18,0.01), V3(0,1.25,0.105), "plastic.black", r: 0.01)
        bx(&m, V3(0.1,0.02,0.01), V3(0,1.1,0.106), "plastic.orange"); bx(&m, V3(0.08,0.2,0.08), V3(0.14,0.85,0.13), "plastic.black", r: 0.02)
        m.add(Prim.tube([V3(0.14,0.88,0.13),V3(0.2,0.7,0.2),V3(0.1,0.5,0.22),V3(-0.1,0.5,0.14),V3(-0.15,0.7,0.1)], radii: [0.012,0.012,0.012,0.012,0.012], sides: 8, seamTile: 0.2, material: "plastic.black", capEnd: true))
        groundAO(&m, height: 0.2, floor: 0.6)
        return LODModel(m)
    }
}
