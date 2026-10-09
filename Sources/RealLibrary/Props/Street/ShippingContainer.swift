import simd
import Foundation

public struct ShippingContainer: RealAsset {
    public static let id = "shipping-container"
    public static let summary = "20 ft corrugated steel shipping container, 6.1 m, locking rods, corner castings and door seals."
    public static let tags = ["prop", "harbor", "industrial", "metal"]
    public static let budget = 14000
    public init() {}
    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)

        let c: MaterialKey = "metal.painted:8E3B2E"
        bx(&m, V3(6.05,2.4,2.3), V3(0,1.26,0), c, r: 0.01)
        for i in 0..<28 { bx(&m, V3(0.06,2.2,0.04), V3(-2.9+Float(i)*0.215,1.26,1.16), c, r: 0.012); bx(&m, V3(0.06,2.2,0.04), V3(-2.9+Float(i)*0.215,1.26,-1.16), c, r: 0.012) }
        for x: Float in [-1,1] { for y: Float in [0.06,2.46] { for z: Float in [-1,1] { bx(&m, V3(0.16,0.12,0.16), V3(x*3.0,y,z*1.1), "metal.cast-iron-street") } } }
        for s: Float in [-1,1] { for i in 0..<4 { rod(&m, V3(3.02,0.21,s*0.1+Float(i)*0.0),V3(3.02,2.31,s*0.1), 0.012, "metal.steel", sides: 8) } }
        for s: Float in [-1,1] { for z: Float in [-1,1] { bx(&m, V3(0.04,0.04,0.2), V3(3.04,0.06,z*0.5), "metal.steel") }; _ = s }
        groundAO(&m, height: 0.2, floor: 0.6)
        return LODModel(m)
    }
}
