import simd
import Foundation

/// Fresh mozzarella (fior di latte) ball, 125 g, 6.5 cm: a glossy milk-white sphere settled a little
/// flat on its base, with the twisted knot where the curd was pinched closed on top. One closed
/// shell; cut face `food.mozzarella-section` (layered, fibrous). Cook kind `dairy`: melts and browns.
public struct MozzarellaBall: RealFood {
    public static let id = "mozzarella-ball"
    public static let summary = "Fresh mozzarella ball, 6.5 cm: glossy milk-white skin, pinched closing knot, fibrous white section; melts and browns."
    public static let tags = ["prop", "food", "kitchen", "handheld"]
    public static let budget = 6000
    public static let author = "realityhd"
    public static let kind = FoodKind.dairy
    public static let preview = PreviewHint(azimuth: 30, elevation: 25, distance: 0.22, studio: true)

    /// Diameter (m).
    public var diameter: Float = 0.066
    /// Height as a fraction of the diameter (settled).
    public var settle: Float = 0.86
    /// Material keys.
    public var skin: MaterialKey = "food.mozzarella"
    public var section: MaterialKey = "food.mozzarella-section"
    public init() {}

    public var coreCenter: V3 { V3(0, diameter * settle / 2, 0) }

    public func capMaterial(for key: MaterialKey) -> MaterialKey? { key == skin ? section : nil }

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        let R = diameter / 2, H = diameter * settle
        // Profile with the knot: a small pinched nub at the top pole.
        let prof: [V2] = [V2(0, 0), V2(R * 0.5, 0.0006), V2(R * 0.82, H * 0.07), V2(R * 0.98, H * 0.25), V2(R, H * 0.45),
                          V2(R * 0.95, H * 0.66), V2(R * 0.78, H * 0.84), V2(R * 0.45, H * 0.965), V2(R * 0.16, H * 0.995),
                          V2(R * 0.1, H * 1.005), V2(R * 0.07, H * 1.03), V2(R * 0.03, H * 1.045), V2(0, H * 1.048)]
        var s = FoodMesh.revolve(edge: 0.0032, seamTile: 0.06, material: skin, curve: FoodMesh.profile(prof))
        let sd = UInt32(truncatingIfNeeded: seed)
        let twist = rng.float(2...4)
        s.deform { p in
            // Knot twist and gathered folds around the pole.
            let t = smoothstep(H * 0.8, H * 1.05, p.y)
            let a = atan2(p.z, p.x)
            let fold = 1 + 0.18 * t * sin(6 * a + twist * t * 6)
            return V3(p.x * fold, p.y, p.z * fold)
        }
        s.displace { p, _ in RecipeMesh.noise(p, 30, seed: sd) * 0.0008 + RecipeMesh.noise(p, 80, seed: sd &+ 1) * 0.0002 }
        s = FoodMesh.boxUV(s)
        var m = Model(name: Self.id)
        m.add(s)
        let b = m.bounds
        m = m.transformed(Xform(translation: V3(-(b.min.x + b.max.x) / 2, -b.min.y, -(b.min.z + b.max.z) / 2)))
        groundAO(&m, height: 0.012, floor: 0.6)
        return LODModel(m)
    }
}
