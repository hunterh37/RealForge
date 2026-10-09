import simd
import Foundation

public struct SawhorseBarrier: RealAsset {
    public static let id = "sawhorse-barrier"
    public static let summary = "Orange and white sawhorse barrier, 1.2 m, striped plastic rail on two folding steel A-legs."
    public static let tags = ["prop", "road", "barrier", "construction", "plastic"]
    public static let budget = 5500
    public init() {}
    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)

        for i in 0..<4 { bx(&m, V3(0.3,0.2,0.03), V3(-0.45+Float(i)*0.3,0.85,0), i % 2 == 0 ? "plastic.white" : "plastic.orange") }
        for i in 0..<4 { bx(&m, V3(0.3,0.2,0.03), V3(-0.45+Float(i)*0.3,0.62,0), i % 2 == 0 ? "plastic.orange" : "plastic.white") }
        for x: Float in [-0.5,0.5] { for z: Float in [-1,1] { m.add(Prim.tube([V3(x,0.95,0),V3(x,0,z*0.3)], radii:[0.015,0.015], sides: 8, seamTile: 0.2, material: "metal.galvanized", capEnd: true)) } }
        groundAO(&m, height: 0.2, floor: 0.6)
        return LODModel(m)
    }
}
