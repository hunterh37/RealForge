import simd
import Foundation

/// Ripe Hass avocado lying on its side along +X (stem end +X). Three nested closed shells: a 2 mm
/// pebbled near-black skin, the buttery flesh with a cavity for the seed, and the seed itself
/// (`food.avocado-pit`). Cut lengthwise through the seed it halves like the real fruit: the flesh
/// cap (`food.avocado-flesh`, radial from the seed: yellow around the pit, green toward the skin),
/// the skin's dark rim and the seed's pale section.
public struct Avocado: RealFood {
    public static let id = "avocado"
    public static let summary = "Ripe Hass avocado, 10.5 cm: pebbled dark skin, stem nub, yellow-green flesh around a large brown seed; halves cleanly."
    public static let tags = ["prop", "food", "kitchen", "handheld"]
    public static let budget = 7000
    public static let author = "realityhd"
    public static let kind = FoodKind.vegetable
    public static let preview = PreviewHint(azimuth: 30, elevation: 28, distance: 0.3, studio: true)

    /// Length blossom end to stem (m).
    public var length: Float = 0.105
    /// Max diameter (m).
    public var diameter: Float = 0.07
    /// Skin thickness (m).
    public var skinThickness: Float = 0.002
    /// Material keys.
    public var skin: MaterialKey = "food.avocado-skin"
    public var flesh: MaterialKey = "food.avocado-flesh"
    public var pit: MaterialKey = "food.avocado-pit"
    public var pitCut: MaterialKey = "food.avocado-pit-section"
    public var stem: MaterialKey = "food.stem-green:5E4A2E"
    public init() {}

    var pitY: Float { length * 0.33 }

    public var coreCenter: V3 { V3(pitY - length / 2, diameter / 2, 0) }

    public func capMaterial(for key: MaterialKey) -> MaterialKey? {
        switch key {
        case skin: return skin
        case flesh: return flesh
        case pit: return pitCut
        default: return nil
        }
    }

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        let L = length, R = diameter / 2
        let prof: [V2] = [V2(0, 0), V2(R * 0.5, L * 0.025), V2(R * 0.86, L * 0.11), V2(R, L * 0.29), V2(R * 0.97, L * 0.43),
                          V2(R * 0.84, L * 0.6), V2(R * 0.66, L * 0.76), V2(R * 0.46, L * 0.89), V2(R * 0.22, L * 0.975), V2(0, L)]
        let curve = FoodMesh.profile(prof)
        var outer = FoodMesh.revolve(edge: 0.0042, seamTile: 0.06, material: skin, curve: curve)
        let ph = (0..<3).map { _ in rng.float(0...6.28) }
        let sd = UInt32(truncatingIfNeeded: seed)
        let lump: (V3) -> V3 = { p in
            let a = atan2(p.z, p.x), t = p.y / L
            let k = 1 + 0.035 * sin(a + ph[0]) * sin(.pi * t) + 0.015 * sin(2 * a + ph[1] + t * 4)
            return V3(p.x * k, p.y, p.z * k)
        }
        outer.deform(lump)
        outer.displace { p, _ in 0.00035 * RecipeMesh.noise(p, 260, seed: sd &+ 11) + 0.0003 * RecipeMesh.noise(p, 90, seed: sd &+ 12) }
        // Hidden inner walls use a coarser inset revolve of the same profile.
        func inset(_ d: Float, material: MaterialKey) -> Surface {
            var s = FoodMesh.revolve(edge: 0.0065, seamTile: 0.06, material: material) { t in
                let q = curve(t)
                return V2(max(0, q.x - d), d + (q.y) * (L - 2.2 * d) / L)
            }
            s.deform(lump)
            return s
        }
        let inner = inset(skinThickness, material: skin)
        var rind = outer
        rind.append(inner.flipped())
        // Seed: a slightly pointed ellipsoid in the wide end.
        let pr: Float = 0.0185, pl: Float = 0.044
        let pitS = FoodMesh.revolve(edge: 0.0035, seamTile: 0.04, material: pit) { t in
            let a = Float.pi * t
            return V2(pr * sin(a) * (1 - 0.12 * t), pitY - pl / 2 + pl * (0.5 - 0.5 * cos(a)))
        }
        var fleshS = inset(skinThickness + 0.0003, material: flesh)
        fleshS.append(FoodMesh.offset(pitS, by: 0.0003, material: flesh).flipped())
        // Stem nub in a shallow dimple at the narrow end.
        let top = V3(0, L, 0)
        let bend = rng.float(-1...1)
        let sp = [top - V3(0, 0.003, 0), top + V3(0.0006 * bend, 0.0018, 0), top + V3(0.0012 * bend, 0.0042, 0.0004)]
        let stemS = FoodMesh.tube(sp, radii: [0.0026, 0.0021, 0.0017], sides: 9, endBulge: 0.15, material: stem)
        var m = Model(name: Self.id)
        m.add(FoodMesh.layAlongX(rind))
        m.add(FoodMesh.layAlongX(fleshS))
        m.add(FoodMesh.layAlongX(pitS))
        m.add(FoodMesh.layAlongX(stemS))
        m = m.transformed(Xform(translation: V3(-L / 2, R * 1.02, 0)))
        let b = m.bounds
        m = m.transformed(Xform(translation: V3(0, -b.min.y, 0)))
        groundAO(&m, height: 0.012, floor: 0.6)
        return LODModel(m)
    }
}
