import simd
import Foundation

/// Ripe garden strawberry lying on its side along +X (tip -X, calyx +X). One closed glossy berry
/// with seeded pits in `food.strawberry` (cut face `food.strawberry-flesh`: white pith and vascular
/// strands, tile = berry diameter, centered on the long axis), soft shoulders, a star calyx of
/// curled sepals and a short stem.
public struct Strawberry: RealFood {
    public static let id = "strawberry"
    public static let summary = "Ripe strawberry, 4.5 cm: glossy conical berry with seeded pits, green star calyx and stem; pith and strand cut face."
    public static let tags = ["prop", "food", "kitchen", "handheld"]
    public static let budget = 5000
    public static let author = "realityhd"
    public static let kind = FoodKind.vegetable
    public static let preview = PreviewHint(azimuth: 35, elevation: 25, distance: 0.16, studio: true)

    /// Berry length tip to calyx (m).
    public var length: Float = 0.035
    /// Shoulder diameter (m).
    public var diameter: Float = 0.0335
    /// Sepal count.
    public var sepals = 8
    /// Material keys.
    public var skin: MaterialKey = "food.strawberry"
    public var flesh: MaterialKey = "food.strawberry-flesh"
    public var calyx: MaterialKey = "food.stem-green"
    public init() {}

    public var coreCenter: V3 { V3(0, diameter / 2, 0) }

    public func capMaterial(for key: MaterialKey) -> MaterialKey? { key == skin ? flesh : nil }

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        let L = length, R = diameter / 2
        // Along +Y: tip at y = 0, calyx end at y = L.
        let profile: [V2] = [V2(0, 0), V2(R * 0.2, L * 0.03), V2(R * 0.45, L * 0.14), V2(R * 0.7, L * 0.34), V2(R * 0.9, L * 0.56),
                             V2(R, L * 0.76), V2(R * 0.95, L * 0.9), V2(R * 0.7, L * 0.98), V2(R * 0.35, L * 1.0), V2(0, L * 0.985)]
        let curve = FoodMesh.profile(profile)
        var body = FoodMesh.revolve(edge: 0.0019, seamTile: 0.04, material: skin, curve: curve)
        let ph = (0..<3).map { _ in rng.float(0...6.28) }
        let shape: (V3) -> V3 = { p in
            let a = atan2(p.z, p.x), t = p.y / L
            let k = 1 + 0.05 * sin(a * 2 + ph[0]) * t + 0.025 * sin(a * 3 + ph[1]) * sin(.pi * t)
            return V3(p.x * k, p.y, p.z * k)
        }
        body.deform(shape)
        let mer = FoodMesh.Meridian(curve, fromTop: true)
        var cal = Surface(material: calyx)
        for i in 0..<sepals {
            var r = rng.fork(i)
            let ang = Float(i) / Float(sepals) * 2 * .pi + r.float(-0.2...0.2) + ph[2]
            let len = r.float(0.009...0.014)
            let curl = r.float(0.5...1.0)
            var leaf = FoodMesh.sepal(length: len, thickness: 0.00025, edge: 0.0012, angle: ang, start: 0.0015, meridian: mer,
                                      material: calyx, width: { t in 0.0026 * pow(sin(.pi * min(1, t * 1.1 + 0.06)), 0.6) * (1 - 0.4 * t) },
                                      lift: { t, x in 0.0004 + 0.0028 * curl * pow(t, 2) + 0.0005 * x * x })
            leaf.deform(shape)
            cal.append(leaf)
        }
        let top = curve(1)
        cal.append(FoodMesh.revolve(edge: 0.001, seamTile: 0.02, material: calyx) { t in
            let a = Float.pi * t
            return V2(0.0035 * sin(a), top.y + 0.0006 - 0.001 * cos(a))
        })
        let bend = rng.float(-1...1)
        let stem = catmull([V3(0, top.y, 0), V3(0.0008 * bend, top.y + 0.006, 0), V3(0.003 * bend, top.y + 0.011, 0.001)], per: 3)
        cal.append(FoodMesh.tube(stem, radii: stem.indices.map { 0.0011 - 0.0002 * Float($0) / Float(stem.count) }, sides: 7,
                                 endBulge: 0.1, material: calyx))
        var m = Model(name: Self.id)
        m.add(FoodMesh.layAlongX(body))
        m.add(FoodMesh.layAlongX(cal))
        let bb = m.bounds
        m = m.transformed(Xform(translation: V3(-(bb.min.x + bb.max.x) / 2, R * 1.05, 0)))
        groundAO(&m, height: 0.008, floor: 0.6)
        return LODModel(m)
    }
}
