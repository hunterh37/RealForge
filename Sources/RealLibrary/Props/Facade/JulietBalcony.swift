import simd
import Foundation

/// Juliet balcony 1.2 x 1.0 m: wrought iron balusters, scroll panel, top rail and wall plates.
public struct JulietBalcony: RealAsset {
    public static let id = "juliet-balcony"
    public static let summary = "Juliet balcony 1.2 x 1.0 m: wrought iron balusters, scroll panel, top rail and wall plates."
    public static let tags = ["prop", "facade", "window", "metal"]
    public static let budget = 3600
    public static let author = "hunterh37"

    /// Primary material key.
    public var material: String = "metal.painted:222222"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let material = self.material
        let w: Float = 1.2, h: Float = 1.0, d: Float = 0.15
        K.box(&m, V3(0, h - 0.02, 0), V3(w, 0.04, 0.05), material, bevel: 0.006)
        K.box(&m, V3(0, 0.1, 0), V3(w, 0.025, 0.03), material, bevel: 0.004)
        K.box(&m, V3(0, 0.025, 0), V3(w, 0.025, 0.03), material, bevel: 0.004)
        for i in 0...10 { let x = -w / 2 + 0.03 + (w - 0.06) * Float(i) / 10; K.rod(&m, [V3(x, 0.03, 0), V3(x, h - 0.04, 0)], r: 0.008, material, sides: 8) }
        for sx: Float in [-1, 1] {
            K.box(&m, V3(sx * (w / 2 - 0.02), h / 2, 0), V3(0.04, h, 0.04), material, bevel: 0.006)
            K.rod(&m, [V3(sx * (w / 2 - 0.02), h / 2, 0), V3(sx * (w / 2 - 0.02), h / 2, -d)], r: 0.012, material, sides: 8)
        }
        for sx: Float in [-1, 1] { K.rod(&m, K.arc(V3(sx * 0.15, 0.5, 0.03), 0.12, 0, 330, n: 20), r: 0.007, material, sides: 6) }
        K.rod(&m, K.arc(V3(0, 0.5, 0.03), 0.09, 0, 360, n: 20), r: 0.007, material, sides: 6)
        return K.finish(&m, ao: 0.05)
    }
}
