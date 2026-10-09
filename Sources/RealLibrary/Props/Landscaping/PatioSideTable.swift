import simd
import Foundation

public struct PatioSideTable: RealAsset {
    public static let id = "patio-side-table"
    public static let summary = "Round patio side table, 0.5 m diameter x 0.5 m: slatted teak top on a powder-coated steel X base."
    public static let tags = ["prop", "landscaping", "outdoor", "furniture"]
    public static let budget = 4000
    public static let author = "realityhd"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let b = "metal.powdercoat"
        m.add(Prim.cylinder(radius: 0.25, height: 0.03, bevel: 0.004, segments: 32, material: "wood.cedar-weathered"), Xform(translation: V3(0, 0.46, 0)))
        K.rod(&m, K.arc(V3(0, 0, 0), 0.24, 0, 360, n: 32).map { V3($0.x, 0.455, $0.y) }, r: 0.008, b, sides: 6)
        for a in 0..<4 {
            let t = Float(a) * .pi / 2 + .pi / 4
            K.rod(&m, [V3(cos(t) * 0.2, 0.455, sin(t) * 0.2), V3(cos(t) * 0.22, 0.01, sin(t) * 0.22)], r: 0.01, b, sides: 6)
        }
        return K.finish(&m)
    }
}
