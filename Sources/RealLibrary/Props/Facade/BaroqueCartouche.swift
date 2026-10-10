import simd
import Foundation

/// Baroque cartouche: a cast-stone shield with rolled scroll borders, a shell crest, acanthus leaves,
/// pendant husks and a recessed blank panel for lettering. Wall plane at z = 0.
public struct BaroqueCartouche: RealAsset {
    public static let id = "baroque-cartouche"
    public static let summary = "Baroque cartouche, 0.7 x 0.95 m: scrolled cast-stone border, shell crest, acanthus, husks, blank panel."
    public static let tags = ["prop", "architecture", "facade", "ornament", "stone"]
    public static let budget = 12000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 24, elevation: 8, distance: 2.0)

    public var width: Float = 0.7
    public var height: Float = 0.95
    public var stone: MaterialKey = "stone.cast-stone"
    public var panel: MaterialKey = "stone.limestone"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let W = width, H = height, cy = H / 2 - 0.02
        m.add(Prim.extrude(Shape2D.superellipse(W * 0.82, H * 0.74, exponent: 3), depth: 0.035, bevel: 0.01, bevelSegments: 2, material: stone),
              Xform(translation: V3(0, cy, 0.0175)))
        m.add(Prim.extrude(Shape2D.superellipse(W * 0.64, H * 0.56, exponent: 3), depth: 0.02, bevel: 0.006, bevelSegments: 1, material: panel),
              Xform(translation: V3(0, cy, 0.04)))
        m.add(Prim.torus(major: 0.2, minor: 0.012, segments: 28, sides: 6, material: stone),
              Xform(translation: V3(0, cy, 0.056), rotation: FA.q(90, FA.X), scale: V3(1.15, 1, 1.6)))
        // Scrolled sides: outward spirals that roll forward.
        for s: Float in [-1, 1] {
            for (y, k) in [(cy + H * 0.26, Float(1)), (cy - H * 0.27, Float(-1))] {
                var pts: [V3] = []
                for i in 0...18 {
                    let t = Float(i) / 18, a = t * 3.0 * .pi, r = 0.085 * (1 - t * 0.8)
                    pts.append(V3(s * (W * 0.34 + 0.07 + r * cos(a) * 0.9), y + k * r * sin(a), 0.05 + t * 0.03))
                }
                FA.path(&m, pts, r: 0.017, stone, sides: 8)
            }
            FA.path(&m, [V3(s * W * 0.41, cy + H * 0.24, 0.045), V3(s * W * 0.44, cy, 0.05), V3(s * W * 0.41, cy - H * 0.24, 0.045)], r: 0.022, stone, sides: 8)
        }
        // Shell crest.
        for k in 0..<9 {
            let a = (Float(k) / 8 - 0.5) * 2.2
            m.add(Prim.superellipsoid(V3(0.05, 0.19, 0.03), exponent: 2.2, subdivisions: 5, material: stone),
                  Xform(translation: V3(sin(a) * 0.12, cy + H * 0.37 + cos(a) * 0.09, 0.05), rotation: FA.q(-a * 180 / .pi, FA.Z)))
        }
        FC.bead(&m, r: 0.03, at: V3(0, cy + H * 0.38, 0.065), stone)
        // Acanthus tufts and pendant husks.
        for s: Float in [-1, 1] {
            for k in 0..<3 {
                m.add(Prim.superellipsoid(V3(0.07, 0.05, 0.02), exponent: 2.2, subdivisions: 5, material: stone),
                      Xform(translation: V3(s * (0.16 + Float(k) * 0.05), cy + H * 0.32 - Float(k) * 0.03, 0.055), rotation: FA.q(s * (-30 + Float(k) * 15), FA.Z)))
            }
            for k in 0..<5 {
                m.add(Prim.superellipsoid(V3(0.028, 0.045 - Float(k) * 0.005, 0.025), exponent: 2, subdivisions: 5, material: stone),
                      Xform(translation: V3(s * 0.05, cy - H * 0.36 - Float(k) * 0.045, 0.05)))
            }
        }
        FA.box(&m, V3(W * 0.5, 0.012, 0.008), V3(0, cy, 0.056), "stone.limestone-sooted", r: 0.001)
        groundAO(&m, height: 0.1, floor: 0.9)
        return LODModel(FC.place(m))
    }
}
