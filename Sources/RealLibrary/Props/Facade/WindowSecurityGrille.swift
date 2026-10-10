import simd
import Foundation

/// Wrought-iron window grille: flat-bar frame, round vertical bars with swelled collars, two scroll
/// panels with spiral ends and a central diamond lozenge. Wall plane at z = 0.
public struct WindowSecurityGrille: RealAsset {
    public static let id = "window-security-grille"
    public static let summary = "Wrought-iron window grille, 0.9 x 1.4 m: flat frame, 12 mm bars with collars, scroll panels, lozenge."
    public static let tags = ["prop", "architecture", "facade", "window", "ornament", "metal"]
    public static let budget = 4500
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 28, elevation: 8, distance: 2.4)

    public var width: Float = 0.9
    public var height: Float = 1.4
    public var barSpacing: Float = 0.11
    public var iron: MaterialKey = "metal.wrought-iron"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let W = width, H = height, d: Float = 0.06
        FA.box(&m, V3(W, 0.03, 0.025), V3(0, 0.015, d), iron, r: 0.003)
        FA.box(&m, V3(W, 0.03, 0.025), V3(0, H - 0.015, d), iron, r: 0.003)
        for s: Float in [-1, 1] { FA.box(&m, V3(0.03, H, 0.025), V3(s * (W / 2 - 0.015), H / 2, d), iron, r: 0.003) }
        let n = Int((W - 0.06) / barSpacing)
        for i in 1...n {
            let x = -W / 2 + 0.015 + Float(i) * (W - 0.03) / Float(n + 1)
            FA.rod(&m, V3(x, 0.03, d), V3(x, H - 0.03, d), r: 0.006, iron, sides: 8)
            for y in [H * 0.33, H * 0.67] { FC.bead(&m, r: 0.011, at: V3(x, y + rng.float(-0.002...0.002), d), iron) }
            FA.path(&m, [V3(x, H - 0.03, d), V3(x, H - 0.005, d), V3(x, H + 0.04, d)], r: 0.004, iron, sides: 6)
            m.add(Prim.cylinder(radius: 0.008, height: 0.06, bevel: 0.002, segments: 8, bevelSegments: 1, material: iron),
                  Xform(translation: V3(x, H - 0.0, d)))
        }
        // Scroll panels top and bottom of the central lozenge.
        for s: Float in [-1, 1] {
            var pts: [V3] = []
            for i in 0...16 {
                let t = Float(i) / 16, a = t * 3.2 * .pi, r = 0.07 * (1 - t * 0.75)
                pts.append(V3(s * (0.1 + 0.07 * cos(a) + t * 0.12), H * 0.5 + 0.0 + 0.07 * sin(a) * s * 0.0 + r * sin(a), d + 0.012))
            }
            FA.path(&m, pts, r: 0.0045, iron, sides: 6)
        }
        m.add(Prim.extrude(Shape2D.polygon(sides: 4, radius: 0.1, rotation: .pi / 4), depth: 0.014, bevel: 0.002, bevelSegments: 1, material: iron),
              Xform(translation: V3(0, H * 0.5, d + 0.012), scale: V3(0.8, 1.0, 1)))
        for y in [H * 0.2, H * 0.8] { FA.box(&m, V3(W - 0.06, 0.012, 0.012), V3(0, y, d), iron, r: 0.002) }
        for p in [V3(-W / 2 + 0.02, 0.08, 0), V3(W / 2 - 0.02, 0.08, 0), V3(-W / 2 + 0.02, H - 0.08, 0), V3(W / 2 - 0.02, H - 0.08, 0)] {
            FA.rod(&m, p, p + V3(0, 0, d), r: 0.009, iron, sides: 8)
        }
        groundAO(&m, height: 0.1, floor: 0.85)
        return LODModel(FC.place(m))
    }
}
