import simd
import Foundation

public struct AntennaMast: RealAsset {
    public static let id = "antenna-mast"
    public static let summary = "Rooftop antenna mast, 3 m, guyed aluminum tube with yagi elements and wall bracket."
    public static let tags = ["prop", "urban", "outdoor", "metal"]
    public static let budget = 4500
    public init() {}
    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)

        cy(&m, 0.2, 0.04, V3(0,0,0), "metal.galvanized")
        rod(&m, V3(0,0.04,0), V3(0,3.0,0), 0.02, "metal.aluminum-brushed")
        for i in 0..<5 { bx(&m, V3(0.9-0.12*Float(i),0.012,0.012), V3(0,2.0+Float(i)*0.18,0), "metal.aluminum-brushed", r: 0.003) }
        for a in [0.0,120.0,240.0] { let t = Float(a) * .pi / 180; rod(&m, V3(0,2.6,0), V3(cos(t)*1.2,0.04,sin(t)*1.2), 0.002, "metal.steel", sides: 6) }
        groundAO(&m, height: 0.2, floor: 0.6)
        return LODModel(m)
    }
}
