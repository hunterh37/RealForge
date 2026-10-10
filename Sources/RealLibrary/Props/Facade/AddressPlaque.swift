import simd
import Foundation

/// Cast brass address plaque 0.25 x 0.15 m with raised numerals, beveled border and four screws.
public struct AddressPlaque: RealAsset {
    public static let id = "address-plaque"
    public static let summary = "Cast brass address plaque 0.25 x 0.15 m with raised numerals, beveled border and four screws."
    public static let tags = ["prop", "facade", "sign", "metal"]
    public static let budget = 3000
    public static let author = "hunterh37"

    /// Primary material key.
    public var material: String = "metal.brass-aged"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let material = self.material
        K.box(&m, V3(0, 0.075, 0), V3(0.25, 0.15, 0.012), material, bevel: 0.003)
        K.box(&m, V3(0, 0.075, 0.007), V3(0.23, 0.13, 0.004), "metal.brass", bevel: 0.001)
        for (i, x) in ([-0.055, 0.0, 0.055] as [Float]).enumerated() {
            let off = Float(i) * 0.0
            K.box(&m, V3(x + off, 0.1, 0.012), V3(0.032, 0.008, 0.008), material, bevel: 0.001)
            K.box(&m, V3(x + off, 0.075, 0.012), V3(0.032, 0.008, 0.008), material, bevel: 0.001)
            K.box(&m, V3(x + off, 0.05, 0.012), V3(0.032, 0.008, 0.008), material, bevel: 0.001)
            K.box(&m, V3(x - 0.012 + off, i == 1 ? 0.0875 : 0.0875, 0.012), V3(0.008, 0.05, 0.008), material, bevel: 0.001)
            K.box(&m, V3(x + 0.012 + off, 0.0625, 0.012), V3(0.008, 0.05, 0.008), material, bevel: 0.001)
        }
        for sx: Float in [-1, 1] { for sy: Float in [0.02, 0.13] { m.add(Prim.cylinder(radius: 0.006, height: 0.006, bevel: 0.001, segments: 10, material: "metal.steel"), Xform(translation: V3(sx * 0.11, sy, 0.0095), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0)))) } }
        return K.finish(&m, ao: 0.05)
    }
}
