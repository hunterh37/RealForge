import simd
import Foundation

public struct PicnicTable: RealAsset {
    public static let id = "picnic-table"
    public static let summary = "Weathered wooden picnic table with attached benches and A-frame legs."
    public static let tags = ["prop", "furniture", "wood", "outdoor"]
    public static let budget = 6_000
    public var length: Float = 1.8
    public init() {}
    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let w: MaterialKey = "wood.weathered"
        for i in 0..<5 {   // tabletop
            m.add(plank(length, 0.14, 0.04, bevel: 0.006, material: w), Xform(translation: V3(0, 0.74, -0.3 + Float(i) * 0.15)).jittered(&rng, deg: 0.4))
        }
        for sz: Float in [-1, 1] { for i in 0..<2 {   // benches
            m.add(plank(length, 0.14, 0.04, bevel: 0.006, material: w), Xform(translation: V3(0, 0.45, sz * (0.62 + Float(i) * 0.15) - sz * 0.075)).jittered(&rng, deg: 0.4))
        }}
        for sx: Float in [-1, 1] {
            let x = sx * (length / 2 - 0.25)
            for sz: Float in [-1, 1] {   // A-frame legs
                let (b, xf) = board(from: V3(x, 0, sz * 0.72), to: V3(x, 0.72, sz * 0.08), width: 0.14, thick: 0.04, up: V3(1, 0, 0), bevel: 0.006, material: w)
                m.add(b, xf.jittered(&rng, deg: 0.4))
            }
            m.add(plank(1.62, 0.1, 0.04, bevel: 0.006, material: w), Xform(translation: V3(x + sx * 0.04, 0.4, 0), rotation: simd_quatf(degrees: 90, axis: .up)))   // bench support
            m.add(plank(0.8, 0.1, 0.04, bevel: 0.006, material: w), Xform(translation: V3(x + sx * 0.04, 0.7, 0), rotation: simd_quatf(degrees: 90, axis: .up)))    // top support
        }
        groundAO(&m, height: 0.35, floor: 0.6)
        return LODModel(m)
    }
}
