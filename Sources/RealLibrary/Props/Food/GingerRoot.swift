import simd
import Foundation

/// Hand of fresh ginger lying flat, 11 cm: a knobby main rhizome along X with three fingers branching
/// off in the XZ plane, each lump pinched at its growth rings and rounded at its end, one end
/// freshly cut. Every lump is its own closed swept shell (overlapping where they join); ringed tan
/// skin in `food.ginger` (u around, v along each lump), yellow fibrous cut face `food.ginger-flesh`.
public struct GingerRoot: RealFood {
    public static let id = "ginger-root"
    public static let summary = "Fresh ginger root, 11 cm: knobby branching rhizome with ringed tan skin and yellow fibrous flesh."
    public static let tags = ["prop", "food", "kitchen", "handheld"]
    public static let budget = 7000
    public static let author = "realityhd"
    public static let kind = FoodKind.root
    public static let preview = PreviewHint(azimuth: 30, elevation: 40, distance: 0.3, studio: true)

    /// Main rhizome length (m).
    public var length: Float = 0.1
    /// Main rhizome radius (m).
    public var radius: Float = 0.014
    /// Material keys.
    public var skin: MaterialKey = "food.ginger"
    public var flesh: MaterialKey = "food.ginger-flesh"
    public init() {}

    public var coreCenter: V3 { V3(0, radius * 0.8, 0) }

    public func capMaterial(for key: MaterialKey) -> MaterialKey? { key == skin ? flesh : nil }

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        let L = length, R = radius
        let sd = UInt32(truncatingIfNeeded: seed)
        var s = Surface(material: skin)
        func lump(_ pts: [V3], r: Float, rings: Float, bulge: Float, phase: Float) -> Surface {
            RecipeMesh.sweep(pts, edge: 0.0032, endBulge: bulge, seamTile: 0.04, material: skin) { t, a in
                let ringT = t * rings + phase
                let pinch = 1 - 0.16 * pow(abs(cos(.pi * ringT)), 10) + 0.03 * sin(ringT * 2.3)
                let end = pow(sin(.pi * min(1, 0.08 + t * 0.92)), 0.35)
                let flat = 1 - 0.18 * cos(a) * cos(a)            // flatter top-bottom: lies flat
                return r * pinch * end * flat * (1 + 0.06 * sin(3 * a + phase * 4))
            }
        }
        let yC = R * 0.85
        let main = (0...8).map { i -> V3 in
            let t = Float(i) / 8
            return V3(-L / 2 + t * L, yC + 0.002 * sin(t * 4), 0.006 * sin(t * 3 + 1))
        }
        s.append(lump(main, r: R, rings: 5, bulge: 0.12, phase: rng.float(0...1)))
        // Fingers: (fraction along the main, angle from +X, length, radius).
        let fingers: [(Float, Float, Float, Float)] = [(0.28, 1.05, 0.038, 0.0105), (0.55, -0.95, 0.034, 0.0098), (0.82, 0.75, 0.03, 0.009)]
        for (k, f) in fingers.enumerated() {
            var r = rng.fork(k)
            let base = main[Int(f.0 * 8)]
            let ang = f.1 + r.float(-0.15...0.15)
            let d = V3(cos(ang), 0, sin(ang))
            let len = f.2 * r.float(0.9...1.1)
            let pts = (0...5).map { i -> V3 in
                let t = Float(i) / 5
                return base + d * (len * t) + V3(0, (f.3 - R) * 0.85 * t + 0.0015 * sin(.pi * t), 0.003 * sin(t * 3) * Float(k % 2 == 0 ? 1 : -1))
            }
            s.append(lump(pts, r: f.3, rings: 3, bulge: 0.7, phase: r.float(0...1)))
        }
        s.displace { p, _ in RecipeMesh.noise(p, 90, seed: sd) * 0.0009 + RecipeMesh.noise(p, 220, seed: sd &+ 1) * 0.0003 }
        var m = Model(name: Self.id)
        m.add(s)
        let b = m.bounds
        m = m.transformed(Xform(translation: V3(-(b.min.x + b.max.x) / 2, -b.min.y, -(b.min.z + b.max.z) / 2)))
        groundAO(&m, height: 0.01, floor: 0.6)
        return LODModel(m)
    }
}
