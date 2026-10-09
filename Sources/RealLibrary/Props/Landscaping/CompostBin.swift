import simd
import Foundation

/// 0.9 m square bin, six side boards 120 mm high, four front boards.
public struct CompostBin: RealAsset {
    public static let id = "compost-bin"
    public static let summary = "Slatted compost bin, 0.95 m: cedar corner posts and gapped boards on three sides, front boards, dark compost mound."
    public static let tags = ["prop", "landscaping", "garden", "outdoor", "container", "wood"]
    public static let budget = 6000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 35, elevation: 18)
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let wood = "wood.lumber-pine"
        for sx: Float in [-1, 1] { for sz: Float in [-1, 1] { K.box(&m, V3(sx * 0.43, 0.475, sz * 0.43), V3(0.06, 0.95, 0.06), wood) } }
        for i in 0..<6 {
            let y: Float = 0.08 + Float(i) * 0.145
            K.box(&m, V3(0, y, -0.445), V3(0.84, 0.12, 0.02), wood)
            for s: Float in [-1, 1] { K.box(&m, V3(s * 0.445, y, 0), V3(0.02, 0.12, 0.84), wood) }
            if i < 4 { K.box(&m, V3(0, y, 0.445), V3(0.84, 0.12, 0.02), wood) }
        }
        let mound = Prim.superellipsoid(V3(0.8, 0.5, 0.8), exponent: 2.5, subdivisions: 8, material: "soil.potting")
        m.add(mound, Xform(translation: V3(0, 0.45, 0)))
        return K.finish(&m)
    }
}
