import simd
import Foundation

public struct PhoneBooth: RealAsset {
    public static let id = "phone-booth"
    public static let summary = "Red steel phone booth, 2.4 m: domed roof, glazed door and sides, crown plate and shelf."
    public static let tags = ["prop", "urban", "street", "metal", "glass"]
    public static let budget = 12000
    public init() {}
    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)

        let red: MaterialKey = "metal.painted:B3201C"
        for (x,z) in [(-0.4,-0.4),(0.4,-0.4),(-0.4,0.4),(0.4,0.4)] { bx(&m, V3(0.05,2.2,0.05), V3(Float(x),1.1,Float(z)), red) }
        bx(&m, V3(0.9,0.06,0.9), V3(0,0.03,0), red); bx(&m, V3(0.9,0.12,0.9), V3(0,2.2,0), red)
        bx(&m, V3(0.8,0.04,0.8), V3(0,2.34,0), red); bx(&m, V3(0.7,0.04,0.7), V3(0,2.4,0), red)
        for s: Float in [-1,1] { bx(&m, V3(0.01,2.0,0.76), V3(s*0.4,1.1,0), "glass.clear"); bx(&m, V3(0.76,2.0,0.01), V3(0,1.1,s*0.4), "glass.clear") }
        for y: Float in [0.5,0.9,1.3,1.7] { bx(&m, V3(0.82,0.02,0.82), V3(0,y,0), red, r: 0.004) }
        bx(&m, V3(0.3,0.04,0.2), V3(0,1.1,-0.28), "metal.stainless")
        groundAO(&m, height: 0.2, floor: 0.6)
        return LODModel(m)
    }
}
