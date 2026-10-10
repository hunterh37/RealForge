import simd
import Foundation

/// Tennis net on two steel posts, 12.8 m between posts, 1.07 m post height, 0.914 m net height at center: white tape, center strap, mesh.
public struct TennisNet: RealAsset {
    public static let id = "tennis-net"
    public static let summary = "Tennis net, 12.8 m between posts: green steel posts, white mesh with headband tape and center strap."
    public static let tags = ["prop", "sports", "park", "outdoor", "metal"]
    public static let budget = 1100
    public static let author = "hunterh37"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let span: Float = 12.8, green = SK.paint(0x2F5D3A)
        for s: Float in [-1, 1] {
            K.box(&m, V3(s * span / 2, 0.02, 0), V3(0.3, 0.04, 0.3), "concrete.rough", bevel: 0.008)
            K.rod(&m, [V3(s * span / 2, 0.04, 0), V3(s * span / 2, 1.07, 0)], r: 0.05, green, sides: 12)
            K.box(&m, V3(s * span / 2, 1.09, 0), V3(0.12, 0.04, 0.12), green, bevel: 0.01)
        }
        K.box(&m, V3(0, 0.45, 0), V3(span, 0.87, 0.008), "fence.chainlink-veil-light", bevel: 0.001)
        K.box(&m, V3(0, 0.9, 0), V3(span, 0.07, 0.014), "fabric.canvas", bevel: 0.003)
        K.box(&m, V3(0, 0.45, 0), V3(0.05, 0.9, 0.012), "fabric.canvas", bevel: 0.003)
        K.rod(&m, [V3(-span / 2, 1.0, 0), V3(0, 0.93, 0), V3(span / 2, 1.0, 0)], r: 0.004, "metal.steel", sides: 5)
        return K.finish(&m, ao: 0.05)
    }
}
