import simd
import Foundation

/// Persian lime lying on its side along +X (stem end -X). Two tissues as nested closed
/// shells with a shared boundary: the rind is a thick-walled shell (pitted waxy skin outside; cut face
/// `food.lime-pith`, white albedo), the flesh is a solid filling it (cut face `food.lime-flesh`,
/// segments centered on the long axis, tile = flesh diameter). A small dried stem button sits in the
/// stem-end dimple.
public struct Lime: RealFood {
    public static let id = "lime"
    public static let summary = "Persian lime, 6.2 cm: glossy pitted green rind, stem button, thin pith, juicy segmented flesh."
    public static let tags = ["prop", "food", "kitchen", "handheld"]
    public static let budget = 6000
    public static let author = "realityhd"
    public static let kind = FoodKind.vegetable
    public static let preview = PreviewHint(azimuth: 30, elevation: 25, distance: 0.21, studio: true)

    /// Length stem end to blossom end (m).
    public var length: Float = 0.062
    /// Diameter (m).
    public var diameter: Float = 0.053
    /// Rind thickness at the equator (m).
    public var rind: Float = 0.0032
    /// Material keys.
    public var skin: MaterialKey = "food.lime"
    public var pith: MaterialKey = "food.lime-pith"
    public var flesh: MaterialKey = "food.lime-flesh"
    public var button: MaterialKey = "food.stem-green:7A7A3A"
    public init() {}

    public var coreCenter: V3 { V3(0, diameter / 2 * 1.02, 0) }

    public func capMaterial(for key: MaterialKey) -> MaterialKey? {
        if key == skin { return pith }
        if key == flesh { return flesh }
        return nil
    }

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        let L = length, R = diameter / 2
        // Along +Y: stem end at y = 0, blossom end at y = L.
        let outerP: [V2] = [V2(0, 0.0028), V2(R * 0.12, 0.0018), V2(R * 0.32, 0.003), V2(R * 0.66, L * 0.1), V2(R * 0.9, L * 0.25),
                            V2(R, L * 0.47), V2(R * 0.97, L * 0.66), V2(R * 0.84, L * 0.82), V2(R * 0.58, L * 0.93),
                            V2(R * 0.28, L * 0.985), V2(R * 0.1, L * 0.997), V2(0, L)]
        let fr = R - rind, f0 = L * 0.08, f1 = L * 0.84
        let fleshCurve: (Float) -> V2 = { t in
            let a = Float.pi * t
            return V2(fr * sin(a) * (1 + 0.04 * sin(a)), f0 + (f1 - f0) * (0.5 - 0.5 * cos(a)))
        }
        var outer = FoodMesh.revolve(edge: 0.0034, seamTile: 0.05, material: skin, curve: FoodMesh.profile(outerP))
        let ph = (0..<3).map { _ in rng.float(0...6.28) }
        outer.deform { p in
            let a = atan2(p.z, p.x), t = p.y / L
            let k = 1 + 0.02 * sin(a * 2 + ph[0]) * sin(.pi * t) + 0.008 * sin(a * 5 + ph[1] + t * 9)
            return V3(p.x * k, p.y, p.z * k)
        }
        let fleshS = FoodMesh.revolve(edge: 0.0042, seamTile: 0.05, material: flesh, curve: fleshCurve)
        var rindS = outer
        rindS.append(fleshS.flipped().with(material: skin))
        // Stem button: a small domed lens in the stem dimple.
        var btn = FoodMesh.revolve(edge: 0.0009, seamTile: 0.01, material: button) { t in
            let a = Float.pi * t
            return V2(0.0034 * sin(a), 0.0026 - 0.0012 * cos(a) - 0.0004 * sin(a))
        }
        btn.deform { p in
            let a = atan2(p.z, p.x)
            let k = 1 + 0.15 * cos(5 * a)
            return V3(p.x * k, p.y, p.z * k)
        }
        var m = Model(name: Self.id)
        m.add(FoodMesh.layAlongX(rindS))
        m.add(FoodMesh.layAlongX(fleshS))
        m.add(FoodMesh.layAlongX(btn))
        m = m.transformed(Xform(translation: V3(-L / 2, R * 1.02, 0)))
        groundAO(&m, height: 0.012, floor: 0.6)
        return LODModel(m)
    }
}
