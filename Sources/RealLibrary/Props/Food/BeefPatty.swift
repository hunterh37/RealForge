import simd
import Foundation

/// 120 g portion of 80/20 ground beef rolled loosely into a ball and set down, so it slumps a little
/// on its base. One closed lumpy shell: large knuckle lumps from hand rolling plus fine coarse-grind
/// worms in the geometry; lean, fat specks and grind crevices live in `food.ground-beef`. The cut
/// face is the same grind. Cook kind `protein` browns it toward `food.ground-beef-cooked`.
public struct BeefPatty: RealFood {
    public static let id = "beef-patty"
    public static let summary = "Ground beef 80/20, 120 g: loosely rolled coarse-grind ball, red lean with white fat specks; browns when cooked."
    public static let tags = ["prop", "food", "kitchen", "handheld"]
    public static let budget = 6000
    public static let author = "realityhd"
    public static let kind = FoodKind.protein
    public static let preview = PreviewHint(azimuth: 30, elevation: 30, distance: 0.22, studio: true)

    /// Ball diameter before slumping (m).
    public var diameter: Float = 0.062
    /// Height after settling, as a fraction of the diameter.
    public var slump: Float = 0.8
    /// Material key.
    public var meat: MaterialKey = "food.ground-beef"
    public init() {}

    public var coreCenter: V3 { V3(0, diameter * slump / 2, 0) }

    public func capMaterial(for key: MaterialKey) -> MaterialKey? { key == meat ? meat : nil }

    public func build(seed: UInt64) -> LODModel {
        let R = diameter / 2
        var s = FoodMesh.revolve(edge: 0.0028, seamTile: 0.05, material: meat) { t in
            let a = Float.pi * t
            return V2(R * sin(a), -R * cos(a))
        }
        let sd = UInt32(truncatingIfNeeded: seed)
        // Slump: flatten, spread at the base, flat contact patch.
        s.deform { p in
            var q = p
            let f = (p.y + R) / (2 * R)
            q.y = -R + (p.y + R) * slump
            let spread = 1 + 0.1 * (1 - smoothstep(0, 0.45, f))
            q.x *= spread; q.z *= spread
            if q.y < -R + 0.002 { q.y = -R + 0.002 - (q.y - (-R + 0.002)) * 0.15 }
            return q
        }
        s.displace { p, n in
            let lump = RecipeMesh.noise(p, 45, seed: sd &+ 1) * 0.0022 + RecipeMesh.noise(p, 110, seed: sd &+ 2) * 0.0008
            let w = Noise.ridged(p * 170, octaves: 2, seed: sd &+ 3)
            let worm = (w - 0.5) * 0.0009
            let base = n.y < -0.8 ? 0.15 : 1
            return (lump + worm) * Float(base)
        }
        s = FoodMesh.boxUV(s)
        var m = Model(name: Self.id)
        m.add(s)
        let b = m.bounds
        m = m.transformed(Xform(translation: V3(-(b.min.x + b.max.x) / 2, -b.min.y, -(b.min.z + b.max.z) / 2)))
        groundAO(&m, height: 0.012, floor: 0.6)
        return LODModel(m)
    }
}
