import simd
import Foundation

/// Mashrabiya timber lattice: a 1.2 x 1.5 m hardwood frame holding turned spindles in a square grid,
/// with an eight-sided star ring in every second cell and a carved cornice cap. Wall plane at z = 0.
public struct MashrabiyaLattice: RealAsset {
    public static let id = "mashrabiya-lattice"
    public static let summary = "Mashrabiya lattice screen, 1.2 x 1.5 m: walnut frame, turned spindle grid, octagonal star rings, cornice cap."
    public static let tags = ["prop", "architecture", "facade", "wood", "ornament"]
    public static let budget = 15_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 28, elevation: 8, distance: 2.8)

    public var width: Float = 1.2
    public var height: Float = 1.5
    public var cell: Float = 0.1
    public var wood: MaterialKey = "wood.walnut"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let W = width, H = height, d: Float = 0.07, f: Float = 0.05
        let cols = Int((W - 2 * f) / cell), rows = Int((H - 2 * f - 0.08) / cell)
        let gw = Float(cols) * cell, gh = Float(rows) * cell
        let x0 = -gw / 2, y0 = f + (H - 0.08 - 2 * f - gh) / 2
        for y in [f / 2, H - 0.08 - f / 2] { FA.box(&m, V3(W, f, d), V3(0, y, d / 2), wood, r: 0.004) }
        for s: Float in [-1, 1] { FA.box(&m, V3(f, H - 0.08, d), V3(s * (W / 2 - f / 2), (H - 0.08) / 2, d / 2), wood, r: 0.004) }
        for c in 0...cols {
            let x = x0 + Float(c) * cell
            FA.rod(&m, V3(x, y0, d / 2), V3(x, y0 + gh, d / 2), r: 0.007, wood, sides: 4)
        }
        for r in 0...rows {
            let y = y0 + Float(r) * cell
            FA.rod(&m, V3(x0, y, d / 2 + 0.012), V3(x0 + gw, y, d / 2 + 0.012), r: 0.007, wood, sides: 4)
        }
        for c in 0...cols {
            for r in 0...rows {
                let p = V3(x0 + Float(c) * cell, y0 + Float(r) * cell, d / 2)
                m.add(Prim.superellipsoid(V3(0.026, 0.026, 0.034), exponent: 2, subdivisions: 2, material: wood), Xform(translation: p + V3(0, 0, 0.006)))
            }
        }
        for c in 0..<cols {
            for r in 0..<rows where (c + r) % 2 == 0 {
                let p = V3(x0 + (Float(c) + 0.5) * cell, y0 + (Float(r) + 0.5) * cell, d / 2 + 0.006)
                m.add(Prim.torus(major: cell * 0.33, minor: 0.0045, segments: 8, sides: 4, material: wood),
                      Xform(translation: p, rotation: FA.q(90, FA.X) * FA.q(22.5, FA.Y)))
            }
        }
        // Carved cornice cap.
        FA.run(&m, [V2(0, 0), V2(0.1, 0), V2(0.1, 0.02), V2(0.07, 0.03), V2(0.07, 0.05), V2(0.02, 0.07), V2(0, 0.08)], length: W + 0.06, at: V3(0, H - 0.08, 0), wood)
        groundAO(&m, height: 0.1, floor: 0.9)
        return LODModel(FC.place(m))
    }
}
