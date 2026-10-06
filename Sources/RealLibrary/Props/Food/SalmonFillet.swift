import simd
import Foundation

/// Skin-on center-cut Atlantic salmon fillet portion lying skin down, 15 x 8 cm. Flesh: a slab with a
/// rounded rectangular plan, 3 cm thick along the back (-Z) tapering to 1.3 cm at the belly (+Z),
/// gently domed with faint flake ripples; myomere fat lines live in `food.salmon` (planar UVs, bands
/// across X). Skin: a thin silver slab under the flesh, proud of it by 0.6 mm all round.
public struct SalmonFillet: RealFood {
    public static let id = "salmon-fillet"
    public static let summary = "Skin-on salmon fillet portion, 15 x 8 x 3 cm: coral flesh with white myomere lines, back-to-belly taper, silver skin."
    public static let tags = ["prop", "food", "kitchen", "handheld"]
    public static let budget = 8000
    public static let author = "realityhd"
    public static let kind = FoodKind.protein
    public static let preview = PreviewHint(azimuth: 30, elevation: 38, distance: 0.38, studio: true)

    /// Length along X (m).
    public var length: Float = 0.15
    /// Width along Z (m).
    public var width: Float = 0.08
    /// Thickness at the back (m).
    public var thickness: Float = 0.03
    /// Belly thickness as a fraction of the back.
    public var belly: Float = 0.42
    /// Material keys.
    public var flesh: MaterialKey = "food.salmon"
    public var skin: MaterialKey = "food.salmon-skin"
    public var fatLine: MaterialKey = "food.salmon-skin:7A6A62"
    public init() {}

    public var coreCenter: V3 { V3(0, thickness * 0.4, 0) }

    public func capMaterial(for key: MaterialKey) -> MaterialKey? {
        if key == flesh { return flesh }
        if key == skin { return skin }
        if key == fatLine { return fatLine }
        return nil
    }

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        let a0 = length / 2, b0 = width / 2, T = thickness, skinT: Float = 0.0016
        let ph = (0..<4).map { _ in rng.float(0...6.28) }
        let radius: (Float) -> Float = { a in
            let c = abs(cos(a)), s = abs(sin(a)), e: Float = 3.4
            let r = 1 / pow(pow(c / a0, e) + pow(s / b0, e), 1 / e)
            return r * (1 + 0.015 * sin(3 * a + ph[0]) + 0.01 * sin(5 * a + ph[1]))
        }
        let outline = RecipeMesh.loop(radius: radius)
        var body = RecipeMesh.slab(outline: outline, thickness: T, bevel: 0.0045, edge: 0.0052, material: flesh)
        let sd = UInt32(truncatingIfNeeded: seed)
        body.deform { p in
            var q = p
            let zn = (p.z / b0 + 1) / 2                  // 0 back, 1 belly
            let xn = p.x / a0
            let prof = 1 - (1 - belly) * smoothstep(0.1, 1.0, zn)
            let along = 1 - 0.08 * xn * xn - 0.04 * xn
            let f = p.y / T
            let top = smoothstep(0.4, 1, f)
            let ripple = 0.00035 * sin(p.x * 2 * .pi / 0.011 + 3 * sin(p.z * 40 + ph[2])) * smoothstep(0.2, 0.9, 1 - abs(xn))
            let n = RecipeMesh.noise(V3(p.x, 0, p.z), 30, seed: sd &+ 7)
            q.y = p.y * prof * along + top * (ripple + 0.0006 * n) + skinT * 0.75
            return q
        }
        body = FoodMesh.boxUV(body)
        var skinS = RecipeMesh.slab(outline: RecipeMesh.offsetLoop(outline, by: 0.0006), thickness: skinT, bevel: 0.0007,
                                    edge: 0.006, bevelSegments: 2, material: skin)
        skinS.deform { p in
            let zn = (p.z / b0 + 1) / 2
            return V3(p.x, p.y + 0.0002 * sin(zn * 9 + ph[3]), p.z)
        }
        // Grey-brown subcutaneous fat line between the skin and the flesh, proud of the flesh edge.
        var fatS = RecipeMesh.slab(outline: RecipeMesh.offsetLoop(outline, by: 0.0003), thickness: 0.0016, bevel: 0.0006,
                                   edge: 0.007, bevelSegments: 2, material: fatLine)
        fatS.deform { p in V3(p.x, p.y + skinT * 0.6, p.z) }
        var m = Model(name: Self.id)
        m.add(body)
        m.add(skinS)
        m.add(fatS)
        let b = m.bounds
        m = m.transformed(Xform(translation: V3(-(b.min.x + b.max.x) / 2, -b.min.y, -(b.min.z + b.max.z) / 2)))
        groundAO(&m, height: 0.01, floor: 0.7)
        return LODModel(m)
    }
}
