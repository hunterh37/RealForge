import simd
import Foundation

public struct Flagpole: RealAsset {
    public static let id = "flagpole"
    public static let summary = "Tapered aluminum flagpole, 7 m, gold ball finial, truss head, rope cleat and halyard."
    public static let tags = ["prop", "urban", "outdoor", "metal"]
    public static let budget = 3000
    public init() {}
    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)

        cy(&m, 0.12, 0.08, V3(0,0,0), "concrete.smooth")
        m.add(turned([(0,0.08),(0.055,0.08),(0.04,2.5),(0.03,7),(0,7)], segments: 24, material: "metal.aluminum-brushed", seamTile: 0.3))
        m.add(Prim.cubeSphere(subdivisions: 3, material: "metal.brass") { $0 * 0.05 }, Xform(translation: V3(0,7.05,0)))
        bx(&m, V3(0.1,0.02,0.02), V3(0.03,1.4,0), "metal.aluminum-brushed")
        rod(&m, V3(0.05,1.8,0.05), V3(0.05,6.8,0.05), 0.004, "plastic.white")
        groundAO(&m, height: 0.2, floor: 0.6)
        return LODModel(m)
    }
}
