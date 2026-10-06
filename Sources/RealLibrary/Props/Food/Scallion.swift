import simd
import Foundation

/// Scallion (green onion) lying along +X, 30 cm: a white bulb end with a tuft of fine roots at -X, a
/// pale sheath, and green tubular leaves that split into three and taper to points. The white shaft
/// and the green leaves are separate closed shells (the green sheath wraps the white where they
/// meet); both cut to concentric rings (`food.scallion-section`). Cook kind `leaf`.
public struct Scallion: RealFood {
    public static let id = "scallion"
    public static let summary = "Scallion, 30 cm: white bulb with fine roots, hollow green leaves splitting into three."
    public static let tags = ["prop", "food", "kitchen", "handheld"]
    public static let budget = 6000
    public static let author = "realityhd"
    public static let kind = FoodKind.leaf
    public static let preview = PreviewHint(azimuth: 25, elevation: 45, distance: 0.5, studio: true)

    /// Overall length without roots (m).
    public var length: Float = 0.29
    /// Shaft radius (m).
    public var shaftRadius: Float = 0.0052
    /// Material keys.
    public var white: MaterialKey = "food.scallion-white"
    public var green: MaterialKey = "food.scallion-green"
    public var section: MaterialKey = "food.scallion-section"
    public var root: MaterialKey = "food.scallion-root"
    public init() {}

    public var coreCenter: V3 { V3(0, shaftRadius, 0) }

    public func capMaterial(for key: MaterialKey) -> MaterialKey? { key == white || key == green ? section : nil }

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        let L = length, r0 = shaftRadius
        let y = r0
        // White shaft with a slight bulb near the root end.
        let wPath = (0...6).map { V3(Float($0) / 6 * 0.095, y, 0) }
        let whiteS = RecipeMesh.sweep(wPath, edge: 0.003, endBulge: 0.25, seamTile: 0.03, material: white) { t, a in
            let bulb = 1 + 0.25 * exp(-pow((t - 0.08) / 0.08, 2))
            return r0 * bulb * (1 - 0.06 * t - 0.25 * smoothstep(0.8, 1, t)) * (1 - 0.06 * sin(a) * sin(a))
        }
        var m = Model(name: Self.id)
        m.add(whiteS)
        // Green sheath from x = 0.075 to the split.
        let split: Float = 0.16
        let gPath = (0...8).map { V3(0.075 + Float($0) / 8 * (split - 0.075 + 0.01), y + 0.0002, 0) }
        var greens = Surface(material: green)
        greens.append(RecipeMesh.sweep(gPath, edge: 0.003, endBulge: 0.4, seamTile: 0.03, material: green) { t, a in
            (r0 * 0.96 + 0.0003 * smoothstep(0, 0.15, t)) * (1 - 0.08 * t) * (1 - 0.08 * sin(a) * sin(a))
        })
        // Three leaves diverging from the split, flattening and drooping to the counter.
        let spread: [Float] = [-0.06, 0.01, 0.07]
        for (k, s) in spread.enumerated() {
            var r = rng.fork(k)
            let len = (L - split) * r.float(0.85...1.05)
            let ang = s + r.float(-0.02...0.02)
            let pts: [V3] = (0...10).map { i in
                let t = Float(i) / 10
                let x = split - 0.012 + t * len
                return V3(x, y * (1 - 0.6 * t) + 0.001 * sin(.pi * t), sin(ang) * t * len + 0.004 * sin(t * 4 + Float(k)))
            }
            let rad = r0 * r.float(0.6...0.72)
            greens.append(RecipeMesh.sweep(pts, edge: 0.0032, endBulge: 0.6, seamTile: 0.03, material: green) { t, a in
                let taper = max(0.05, 1 - pow(t, 1.6)) * (1 - 0.15 * t)
                let flat = 1 - 0.35 * t * sin(a) * sin(a) - 0.25 * t * cos(a) * cos(a) * 0
                return rad * taper * flat
            })
        }
        m.add(greens)
        // Fine roots from the basal plate.
        var roots = Surface(material: root)
        for k in 0..<14 {
            var r = rng.fork(100 + k)
            let a = r.float(0...6.28), len = r.float(0.008...0.02)
            let dir = simd_normalize(V3(-1, 0.5 * sin(a) * r.float(0.5...1.2), 0.9 * cos(a) * r.float(0.5...1.2)))
            let base = V3(-0.0005, y + r0 * 0.5 * sin(a), r0 * 0.5 * cos(a))
            var pts: [V3] = []
            for i in 0...3 {
                let t = Float(i) / 3
                var p = base + dir * len * t
                p.y = max(0.0004, p.y - 0.004 * t * t)
                p.z += 0.002 * sin(t * 5 + a) * t
                pts.append(p)
            }
            roots.append(FoodMesh.tube(pts, radii: [0.00045, 0.0004, 0.00032, 0.00022], sides: 4, endBulge: 0.5, material: root))
        }
        m.add(roots)
        let b = m.bounds
        m = m.transformed(Xform(translation: V3(-(b.min.x + b.max.x) / 2, -b.min.y, -(b.min.z + b.max.z) / 2)))
        groundAO(&m, height: 0.006, floor: 0.7)
        return LODModel(m)
    }
}
