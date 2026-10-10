import simd
import Foundation

/// Portable event toilet, 1.15 m square and 2.35 m tall: molded plastic cabin, door with latch, roof vent, sloped roof.
public struct PortableToilet: RealAsset {
    public static let id = "portable-toilet"
    public static let summary = "Portable event toilet, 2.35 m: molded plastic cabin with door and latch, roof vent and ribbed sloped roof."
    public static let tags = ["prop", "construction", "outdoor", "plastic"]
    public static let budget = 4000
    public static let author = "hunterh37"

    /// Cabin color, sRGB hex.
    public var cabinColor: UInt32 = 0x2E7D5B
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let body = MaterialKey(stringLiteral: "metal.painted:" + String(cabinColor, radix: 16, uppercase: true)), W: Float = 1.15
        bx(&m, V3(W, 0.18, W), V3(0, 0.09, 0), "plastic.white", r: 0.02, bs: 2)
        bx(&m, V3(W - 0.04, 1.95, W - 0.04), V3(0, 1.15, 0), body, r: 0.03, bs: 2)
        bx(&m, V3(W + 0.04, 0.12, W + 0.04), V3(0, 2.18, 0), "plastic.white", r: 0.02, bs: 2)
        bx(&m, V3(W - 0.02, 0.06, W - 0.02), V3(0, 2.27, 0), "plastic.white", r: 0.02, bs: 2)
        bx(&m, V3(0.78, 1.72, 0.02), V3(0, 1.08, W / 2 - 0.005), body, r: 0.012, bs: 2)
        for y: Float in [0.5, 0.9, 1.3, 1.7] { bx(&m, V3(0.72, 0.012, 0.012), V3(0, y, W / 2 + 0.012), "plastic.white", r: 0.003) }
        bx(&m, V3(0.06, 0.12, 0.03), V3(0.28, 1.1, W / 2 + 0.02), "plastic.gloss", r: 0.008)
        bx(&m, V3(0.10, 0.07, 0.01), V3(0.28, 1.34, W / 2 + 0.012), "plastic.orange", r: 0.004)
        for y: Float in [0.4, 1.0, 1.7] { bx(&m, V3(0.04, 0.12, 0.03), V3(-0.4, y, W / 2 + 0.01), "plastic.white", r: 0.006) }
        m.add(Prim.cylinder(radius: 0.05, height: 0.14, bevel: 0.008, segments: 16, material: "plastic.white"), Xform(translation: V3(-0.3, 2.3, -0.3)))
        for i in 0..<5 { bx(&m, V3(W - 0.1, 0.02, 0.025), V3(0, 2.31, -0.35 + Float(i) * 0.15), "plastic.white", r: 0.005) }
        return K.finish(&m, ao: 0.2)
    }
}
