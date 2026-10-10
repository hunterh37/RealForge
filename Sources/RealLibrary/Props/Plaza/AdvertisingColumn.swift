import simd
import Foundation

/// Cast-iron advertising column (Litfass type), 1.2 m across and 3.2 m tall: plinth, poster drum, domed cap.
public struct AdvertisingColumn: RealAsset {
    public static let id = "advertising-column"
    public static let summary = "Cast-iron advertising column, 3.2 m: moulded plinth, paper-wrapped poster drum, domed copper cap."
    public static let tags = ["prop", "urban", "street", "sign", "metal"]
    public static let budget = 3100
    public static let author = "hunterh37"

    /// Poster drum radius in meters.
    public var radius: Float = 0.6
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let r = radius
        m.add(turned([(0, 0), (r + 0.06, 0), (r + 0.06, 0.06), (r + 0.02, 0.1), (r + 0.02, 0.5), (r + 0.06, 0.56), (r + 0.06, 0.62), (r, 0.66), (0, 0.66)],
                     segments: 40, material: "metal.painted:2F4A3C"))
        let bands = 12
        for i in 0..<bands {
            let a0 = Float(i) / Float(bands) * .pi * 2
            let c = rng.float(0...1)
            let tone: UInt32 = c < 0.33 ? 0xE8E2D2 : (c < 0.66 ? 0xD9CBA7 : 0xCFD8DC)
            m.add(Prim.roundedBox(V3(0.012, 1.95, 2 * (r - 0.02) * tan(.pi / Float(bands))), radius: 0.003, bevelSegments: 1,
                                  material: MaterialKey(stringLiteral: "metal.painted:" + String(tone, radix: 16, uppercase: true))),
                  Xform(translation: V3(cos(a0) * (r - 0.02), 1.66, sin(a0) * (r - 0.02)), rotation: simd_quatf(degrees: -a0 * 180 / .pi, axis: .up)))
        }
        m.add(turned([(0, 2.62), (r + 0.05, 2.62), (r + 0.05, 2.70), (r - 0.02, 2.76), (r - 0.02, 2.86), (0.3, 3.05), (0.1, 3.14), (0.1, 3.2), (0, 3.22)],
                     segments: 40, material: "metal.copper-patina"))
        return K.finish(&m, ao: 0.3)
    }
}
