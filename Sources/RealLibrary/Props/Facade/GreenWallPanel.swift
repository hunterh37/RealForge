import simd
import Foundation

/// Modular green wall panel 1.5 x 2.0 m: powder-coated steel tray with felt pockets and a grid of mounded foliage.
public struct GreenWallPanel: RealAsset {
    public static let id = "green-wall-panel"
    public static let summary = "Modular green wall panel 1.5 x 2.0 m: powder-coated steel tray with felt pockets and a grid of mounded foliage."
    public static let tags = ["prop", "facade", "wall", "garden", "metal"]
    public static let budget = 6200
    public static let author = "hunterh37"

    /// Primary material key.
    public var material: String = "metal.painted:3A3D40"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let material = self.material
        let w: Float = 1.5, h: Float = 2.0, d: Float = 0.2
        K.box(&m, V3(0, h / 2, -d / 2 + 0.02), V3(w, h, 0.04), material, bevel: 0.006)
        var rng = SeededRNG(seed: seed)
        for r in 0..<8 {
            let y = 0.12 + (h - 0.24) * Float(r) / 7
            K.box(&m, V3(0, y - 0.07, -d / 2 + 0.09), V3(w - 0.04, 0.012, 0.16), material, bevel: 0.003)
            K.box(&m, V3(0, y - 0.02, -d / 2 + 0.17), V3(w - 0.04, 0.12, 0.012), "fabric.canvas", bevel: 0.003)
            for c in 0..<6 {
                let x = -w / 2 + 0.14 + (w - 0.28) * Float(c) / 5 + rng.float(-0.02...0.02)
                m.add(Prim.superellipsoid(V3(0.2, 0.15, 0.17), exponent: 2.4, subdivisions: 2, material: (r + c) % 3 == 0 ? "moss.cushion" : "leaf.boxwood"), Xform(translation: V3(x, y + 0.02, -d / 2 + 0.2)))
            }
        }
        return K.finish(&m, ao: 0.05)
    }
}
