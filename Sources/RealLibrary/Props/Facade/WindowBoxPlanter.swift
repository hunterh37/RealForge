import simd
import Foundation

/// Painted cedar window box 1.0 m with soil, boxwood mounds and trailing flowers.
public struct WindowBoxPlanter: RealAsset {
    public static let id = "window-box-planter"
    public static let summary = "Painted cedar window box 1.0 m with soil, boxwood mounds and trailing flowers."
    public static let tags = ["prop", "facade", "window", "garden", "wood"]
    public static let budget = 4800
    public static let author = "hunterh37"

    /// Primary material key.
    public var material: String = "wood.painted-exterior:F0EFE8"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let material = self.material
        let w: Float = 1.0, h: Float = 0.2, d: Float = 0.25
        K.box(&m, V3(0, h / 2, 0), V3(w, h, d), material, bevel: 0.006)
        K.box(&m, V3(0, h - 0.04, 0), V3(w - 0.04, 0.02, d - 0.04), "soil.potting", bevel: 0.002)
        var rng = SeededRNG(seed: seed)
        for i in 0..<6 {
            let x = -w / 2 + 0.12 + (w - 0.24) * Float(i) / 5
            m.add(Prim.superellipsoid(V3(0.18, 0.14, 0.18), exponent: 2.4, subdivisions: 2, material: "moss.cushion"), Xform(translation: V3(x, h + 0.01, rng.float(-0.03...0.03))))
            for j in 0..<3 {
                cy(&m, 0.022, 0.015, V3(x + rng.float(-0.06...0.06), h + 0.08 + rng.float(0...0.03), rng.float(-0.06...0.06)), j % 2 == 0 ? "plastic.orange" : "plastic.yellow", bevel: 0.005, seg: 10)
            }
        }
        for sx: Float in [-1, 1] { K.box(&m, V3(sx * (w / 2 - 0.1), -0.05, -d / 2 + 0.01), V3(0.02, 0.1, 0.02), "metal.painted:1A1A1A", bevel: 0.002) }
        return K.finish(&m, ao: 0.05)
    }
}
