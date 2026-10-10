import simd
import Foundation

/// Open-air market stall, 2.4 m wide: four timber posts, canvas awning, trestle counter, produce crates.
public struct MarketStall: RealAsset {
    public static let id = "market-stall"
    public static let summary = "Open-air market stall, 2.4 m wide: timber posts, sloped canvas awning, trestle counter and produce crates."
    public static let tags = ["prop", "urban", "outdoor", "wood", "fabric"]
    public static let budget = 8400
    public static let author = "hunterh37"

    /// Awning fabric material key.
    public var awning = "fabric.canvas"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let W: Float = 2.4, D: Float = 1.6, hF: Float = 2.0, hB: Float = 2.5
        for (x, z, h) in [(-W / 2, D / 2, hF), (W / 2, D / 2, hF), (-W / 2, -D / 2, hB), (W / 2, -D / 2, hB)] {
            K.box(&m, V3(x, h / 2, z), V3(0.07, h, 0.07), "wood.weathered", bevel: 0.004)
        }
        let a = V3(-W / 2 - 0.1, hF + 0.03, D / 2 + 0.25), b = V3(-W / 2 - 0.1, hB + 0.03, -D / 2 - 0.1)
        let ang = atan2(b.y - a.y, a.z - b.z) * 180 / .pi
        let len = simd_length(V3(0, b.y - a.y, b.z - a.z))
        m.add(Prim.roundedBox(V3(W + 0.2, 0.012, len), radius: 0.004, material: MaterialKey(stringLiteral: awning)),
              Xform(translation: V3(0, (a.y + b.y) / 2, (a.z + b.z) / 2), rotation: simd_quatf(degrees: -ang, axis: V3(1, 0, 0))))
        m.add(Prim.roundedBox(V3(W + 0.2, 0.24, 0.012), radius: 0.004, material: MaterialKey(stringLiteral: awning)), Xform(translation: V3(0, hF - 0.04, D / 2 + 0.25)))
        K.box(&m, V3(0, 0.88, 0.45), V3(W - 0.1, 0.05, 0.75), "wood.weathered", bevel: 0.004)
        for x in [-W / 2 + 0.2, W / 2 - 0.2] {
            K.beam(&m, V3(x, 0, 0.1), V3(x, 0.86, 0.45), 0.05, 0.05, "wood.weathered")
            K.beam(&m, V3(x, 0, 0.8), V3(x, 0.86, 0.45), 0.05, 0.05, "wood.weathered")
        }
        K.box(&m, V3(0, 0.6, -0.5), V3(W - 0.2, 0.04, 0.5), "wood.weathered", bevel: 0.004)
        for i in 0..<3 {
            let x = -0.75 + Float(i) * 0.75 + rng.float(-0.03...0.03)
            K.box(&m, V3(x, 0.94, 0.45), V3(0.5, 0.12, 0.38), "wood.pine", bevel: 0.006)
            m.add(Prim.superellipsoid(V3(0.42, 0.14, 0.30), exponent: 2, material: i % 2 == 0 ? "plastic.orange" : "plastic.yellow"),
                  Xform(translation: V3(x, 1.04, 0.45)))
        }
        return K.finish(&m, ao: 0.3)
    }
}
