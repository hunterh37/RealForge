import simd
import Foundation

/// Slice of sourdough boule lying flat, 19 x 12 cm and 1.5 cm thick. Two closed shells: the open
/// crumb slab (`food.bread-crumb`, planar UVs, irregular holes) and a slightly thinner crust slab
/// 3.5 mm proud of it all round (`food.bread-crust`), so the crust ring frames both faces. Plan:
/// flat-ish base edge, domed top with a raised ear where the score opened. Cook kind `batter`:
/// toasts golden.
public struct BreadSlice: RealFood {
    public static let id = "bread-slice"
    public static let summary = "Sourdough slice, 19 x 12 x 1.5 cm: open irregular crumb, dark blistered crust ring; toasts golden."
    public static let tags = ["prop", "food", "kitchen", "handheld"]
    public static let budget = 7000
    public static let author = "realityhd"
    public static let kind = FoodKind.batter
    public static let preview = PreviewHint(azimuth: 20, elevation: 50, distance: 0.42, studio: true)

    /// Slice width (m).
    public var width: Float = 0.19
    /// Slice height in plan, base to dome (m).
    public var depth: Float = 0.12
    /// Thickness (m).
    public var thickness: Float = 0.015
    /// Crust thickness (m).
    public var crust: Float = 0.0035
    /// Material keys.
    public var crumb: MaterialKey = "food.bread-crumb"
    public var crustKey: MaterialKey = "food.bread-crust"
    public init() {}

    public var coreCenter: V3 { V3(0, thickness / 2, 0) }

    public func capMaterial(for key: MaterialKey) -> MaterialKey? {
        if key == crumb { return crumb }
        if key == crustKey { return crumb }
        return nil
    }

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        let a0 = width / 2, T = thickness
        let bTop = depth * 0.56, bBot = depth * 0.44
        let earA = rng.float(1.9...2.4), ph = rng.float(0...6.28)
        let radius: (Float) -> Float = { a in
            let s = sin(a)
            let b = s > 0 ? bTop : bBot
            let e: Float = s > 0 ? 2.3 : 2.3 + 2.2 * min(1, -s * 1.6)
            let r = 1 / pow(pow(abs(cos(a)) / a0, e) + pow(abs(s) / b, e), 1 / e)
            let ear = 1 + 0.06 * exp(-pow((a - earA) / 0.18, 2)) - 0.025 * exp(-pow((a - earA - 0.3) / 0.12, 2))
            return r * ear * (1 + 0.008 * sin(7 * a + ph))
        }
        let outline = RecipeMesh.loop(radius: radius)
        let sd = UInt32(truncatingIfNeeded: seed)
        var crumbS = RecipeMesh.slab(outline: RecipeMesh.offsetLoop(outline, by: -crust), thickness: T, bevel: 0.0012, edge: 0.0055,
                                     bevelSegments: 2, material: crumb)
        crumbS.displace { p, n in
            guard abs(n.y) > 0.7 else { return 0 }
            return RecipeMesh.noise(p, 60, seed: sd &+ 2) * 0.0003 + RecipeMesh.noise(p, 25, seed: sd &+ 1) * 0.0004
        }
        crumbS = FoodMesh.planarUV(crumbS)
        var crustS = RecipeMesh.slab(outline: outline, thickness: T - 0.0008, bevel: 0.0032, edge: 0.008, bevelSegments: 3, material: crustKey)
        crustS.deform { p in V3(p.x, p.y + 0.0004, p.z) }
        crustS.displace { p, n in abs(n.y) > 0.7 ? 0 : RecipeMesh.noise(p, 140, seed: sd &+ 3) * 0.0004 }
        crustS = FoodMesh.boxUV(crustS)
        var m = Model(name: Self.id)
        m.add(crumbS)
        m.add(crustS)
        let b = m.bounds
        m = m.transformed(Xform(translation: V3(-(b.min.x + b.max.x) / 2, -b.min.y, -(b.min.z + b.max.z) / 2)))
        groundAO(&m, height: 0.008, floor: 0.7)
        return LODModel(m)
    }
}
