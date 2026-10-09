import simd
import Foundation

public struct SandwichBoard: RealAsset {
    public static let id = "sandwich-board"
    public static let summary = "A-frame sidewalk sandwich board, 0.9 m, two painted boards on hinged legs with a chalk panel."
    public static let tags = ["prop", "urban", "street", "sign", "wood"]
    public static let budget = 3500
    public init() {}
    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)

        let w: MaterialKey = "wood.pine-aged"
        for s: Float in [-1,1] {
            m.add(Prim.roundedBox(V3(0.6,0.85,0.025), radius: 0.004, material: "metal.painted:20262A"), Xform(translation: V3(0,0.43,s*0.2), rotation: simd_quatf(degrees: -s*12, axis: V3(1,0,0))))
        }
        bx(&m, V3(0.56,0.04,0.04), V3(0,0.92,0), w); bx(&m, V3(0.04,0.04,0.5), V3(0.3,0.03,0), w)
        groundAO(&m, height: 0.2, floor: 0.6)
        return LODModel(m)
    }
}
