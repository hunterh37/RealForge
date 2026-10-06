import simd
import Foundation

/// Jalapeno pepper lying on its side along +X (stem end -X): a glossy dark-green pod with broad
/// shoulders tapering to a blunt rounded tip and a slight curve, a cupped five-lobed calyx and a
/// curved stem. Cut across, the pod caps with `food.jalapeno-section` (pale wall, white pith,
/// seeded locules centered on the axis). Cook kind `vegetable`: chars and blisters.
public struct Jalapeno: RealFood {
    public static let id = "jalapeno"
    public static let summary = "Jalapeno, 7.5 cm: glossy dark-green tapering pod, calyx and curved stem, pale seeded section; chars when cooked."
    public static let tags = ["prop", "food", "kitchen", "handheld"]
    public static let budget = 6000
    public static let author = "realityhd"
    public static let kind = FoodKind.vegetable
    public static let preview = PreviewHint(azimuth: 30, elevation: 30, distance: 0.22, studio: true)

    /// Pod length (m).
    public var length: Float = 0.068
    /// Pod diameter at the shoulder (m).
    public var diameter: Float = 0.024
    /// Material keys.
    public var skin: MaterialKey = "food.jalapeno"
    public var section: MaterialKey = "food.jalapeno-section"
    public var calyx: MaterialKey = "food.stem-green"
    public init() {}

    public var coreCenter: V3 { V3(0, diameter / 2, 0) }

    public func capMaterial(for key: MaterialKey) -> MaterialKey? { key == skin ? section : nil }

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        let L = length, R = diameter / 2
        // Along +Y: tip at y = 0, shoulder at y = L.
        let prof: [V2] = [V2(0, 0), V2(R * 0.2, L * 0.012), V2(R * 0.38, L * 0.06), V2(R * 0.58, L * 0.2), V2(R * 0.8, L * 0.45),
                          V2(R * 0.97, L * 0.7), V2(R, L * 0.86), V2(R * 0.9, L * 0.96), V2(R * 0.55, L * 0.995), V2(R * 0.25, L * 1.0),
                          V2(0, L * 0.985)]
        let curve = FoodMesh.profile(prof)
        var pod = FoodMesh.revolve(edge: 0.0026, seamTile: 0.06, material: skin, curve: curve)
        let ph = (0..<3).map { _ in rng.float(0...6.28) }
        let bendK = rng.float(0.004...0.008)
        let shape: (V3) -> V3 = { p in
            let a = atan2(p.z, p.x), t = p.y / L
            let k = 1 + 0.035 * sin(3 * a + ph[0]) * smoothstep(0.1, 0.8, t) + 0.015 * sin(2 * a + ph[1])
            var q = V3(p.x * k, p.y, p.z * k)
            q.z += bendK * pow(1 - t, 2)
            return q
        }
        pod.deform(shape)
        var m = Model(name: Self.id)
        // Calyx: a shallow cup with five lobes over the shoulder.
        let top = curve(1)
        var cal = FoodMesh.revolve(edge: 0.0014, seamTile: 0.02, material: calyx) { t in
            let a = Float.pi * t
            return V2(0.0068 * sin(a), top.y - 0.0016 + 0.0034 * (0.5 - 0.5 * cos(a)) - 0.0006 * sin(a))
        }
        cal.deform { p in
            let a = atan2(p.z, p.x)
            let k = 1 + 0.18 * cos(5 * a + ph[2])
            var q = V3(p.x * k, p.y, p.z * k)
            q.y -= 0.0012 * max(0, cos(5 * a + ph[2])) * simd_length(V2(p.x, p.z)) / 0.007
            return shape(q)
        }
        let bend = rng.float(-1...1)
        let sp = catmull([V3(0, top.y - 0.001, 0), V3(0.002 * bend, top.y + 0.008, 0.001), V3(0.007 * bend, top.y + 0.016, 0.003),
                          V3(0.012 * bend, top.y + 0.021, 0.004)], per: 3)
        let stemS = FoodMesh.tube(sp, radii: sp.indices.map { 0.0022 - 0.0005 * Float($0) / Float(sp.count - 1) }, sides: 9,
                                  endBulge: 0.1, material: calyx)
        var c = Surface(material: calyx)
        c.append(cal)
        c.append(stemS)
        m.add(FoodMesh.layAlongX(pod))
        m.add(FoodMesh.layAlongX(c))
        // Stem end toward -X: mirror X after laying along X (tip at -X otherwise).
        m = m.transformed(Xform(rotation: simd_quatf(angle: .pi, axis: V3(0, 1, 0))))
        let b = m.bounds
        m = m.transformed(Xform(translation: V3(-(b.min.x + b.max.x) / 2, -b.min.y, -(b.min.z + b.max.z) / 2)))
        groundAO(&m, height: 0.01, floor: 0.6)
        return LODModel(m)
    }
}
