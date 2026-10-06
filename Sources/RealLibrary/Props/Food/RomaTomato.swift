import simd
import Foundation

/// Ripe roma (plum) tomato lying on its side along +X, stem end at +X. One closed glossy body whose
/// cut face is the locular cross section (`food.tomato-flesh`: pericarp wall, septa, gel and seeds,
/// tile = body diameter, centered on the long axis), slight three-lobe shoulders, a shallow stem
/// dimple, a star calyx of five curled sepals and a short stem stub.
public struct RomaTomato: RealFood {
    public static let id = "roma-tomato"
    public static let summary = "Ripe roma tomato, 7.5 cm: glossy plum-shaped fruit on its side with green star calyx; flesh shell with locular cut face."
    public static let tags = ["prop", "food", "kitchen", "handheld"]
    public static let budget = 6000
    public static let author = "realityhd"
    public static let kind = FoodKind.vegetable
    public static let preview = PreviewHint(azimuth: 35, elevation: 25, distance: 0.26, studio: true)

    /// Length stem to blossom end (m).
    public var length: Float = 0.07
    /// Diameter (m).
    public var diameter: Float = 0.051
    /// Sepal count.
    public var sepals = 5
    /// Material keys.
    public var skin: MaterialKey = "food.tomato"
    public var flesh: MaterialKey = "food.tomato-flesh"
    public var calyx: MaterialKey = "food.stem-green"
    public init() {}

    public var coreCenter: V3 { V3(0, diameter / 2, 0) }

    public func capMaterial(for key: MaterialKey) -> MaterialKey? { key == skin ? flesh : nil }

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        let L = length, R = diameter / 2
        // Built along +Y: blossom end at y = 0, stem end at y = L.
        let profile: [V2] = [V2(0, 0.0004), V2(R * 0.35, L * 0.03), V2(R * 0.68, L * 0.1), V2(R * 0.9, L * 0.24), V2(R, L * 0.45),
                             V2(R * 0.98, L * 0.66), V2(R * 0.88, L * 0.84), V2(R * 0.64, L * 0.96), V2(R * 0.32, L * 0.995),
                             V2(R * 0.1, L * 0.985), V2(0, L * 0.982)]
        let curve = FoodMesh.profile(profile)
        var body = FoodMesh.revolve(edge: 0.0034, seamTile: 0.06, material: skin, curve: curve)
        let ph = (0..<3).map { _ in rng.float(0...6.28) }
        let lobeShape: (V3) -> V3 = { p in
            let a = atan2(p.z, p.x), t = p.y / L
            let k = 1 + 0.03 * cos(3 * a + ph[0]) * smoothstep(0.3, 0.9, t) + 0.012 * sin(2 * a + ph[1])
            return V3(p.x * k, p.y, p.z * k)
        }
        body.deform(lobeShape)
        var m = Model(name: Self.id)
        // Calyx: sepals curling off the shoulder from the stem scar, then the stem stub.
        let mer = FoodMesh.Meridian(curve, fromTop: true)
        var cal = Surface(material: calyx)
        for i in 0..<sepals {
            var r = rng.fork(i)
            let ang = Float(i) / Float(sepals) * 2 * .pi + r.float(-0.25...0.25) + ph[2]
            let len = r.float(0.011...0.016)
            let curl = r.float(0.6...1.0)
            var leaf = FoodMesh.sepal(length: len, thickness: 0.0003, edge: 0.0016, angle: ang, start: 0.0025, meridian: mer,
                                      material: calyx, width: { t in 0.0024 * pow(sin(.pi * min(1, t * 1.15 + 0.08)), 0.7) * (1 - 0.6 * t) },
                                      lift: { t, x in 0.0004 + 0.0035 * curl * pow(t, 2.5) + 0.0004 * x * x })
            leaf.deform(lobeShape)
            cal.append(leaf)
        }
        // Stem scar ring under the sepals and a short stem stub.
        let top = curve(1)
        cal.append(FoodMesh.revolve(edge: 0.0012, seamTile: 0.02, material: calyx) { t in
            let a = Float.pi * t
            return V2(0.0042 * sin(a), top.y + 0.0004 - 0.0012 * cos(a))
        })
        let bend = rng.float(-1...1)
        let stemPts = catmull([V3(0, top.y - 0.001, 0), V3(0.0005 * bend, top.y + 0.004, 0), V3(0.0018 * bend, top.y + 0.0075, 0.0006)], per: 3)
        cal.append(FoodMesh.tube(stemPts, radii: stemPts.indices.map { 0.0014 - 0.0002 * Float($0) / Float(stemPts.count) }, sides: 8,
                                 endBulge: 0.1, material: calyx))
        m.add(FoodMesh.layAlongX(body))
        m.add(FoodMesh.layAlongX(cal))
        // Lying on its side: axis at y = R (the lobes reach ~3 % further), centered on X.
        m = m.transformed(Xform(translation: V3(-L / 2, R * 1.03, 0)))
        groundAO(&m, height: 0.012, floor: 0.6)
        return LODModel(m)
    }
}
