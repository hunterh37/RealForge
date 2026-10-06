import simd
import Foundation

/// Eureka lemon lying on its side along +X (stem end -X, nipple +X). Two tissues as nested closed
/// shells with a shared boundary: the rind is a thick-walled shell (pitted waxy skin outside; cut face
/// `food.lemon-pith`, white albedo), the flesh is a solid filling it (cut face `food.lemon-flesh`,
/// segments centered on the long axis, tile = flesh diameter). A small dried stem button sits in the
/// stem-end dimple.
public struct Lemon: RealFood {
    public static let id = "lemon"
    public static let summary = "Eureka lemon, 8.5 cm: pitted waxy rind shell with stem button and nipple, white pith, segmented juicy flesh."
    public static let tags = ["prop", "food", "kitchen", "handheld"]
    public static let budget = 6000
    public static let author = "realityhd"
    public static let kind = FoodKind.vegetable
    public static let preview = PreviewHint(azimuth: 30, elevation: 25, distance: 0.27, studio: true)

    /// Length stem end to nipple tip (m).
    public var length: Float = 0.086
    /// Diameter (m).
    public var diameter: Float = 0.0595
    /// Rind thickness at the equator (m).
    public var rind: Float = 0.0055
    /// Material keys.
    public var skin: MaterialKey = "food.lemon"
    public var pith: MaterialKey = "food.lemon-pith"
    public var flesh: MaterialKey = "food.lemon-flesh"
    public var button: MaterialKey = "food.stem-green:6E6A34"
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
        // Along +Y: stem end at y = 0, nipple at y = L.
        let outerP: [V2] = [V2(0, 0.0035), V2(R * 0.12, 0.0022), V2(R * 0.3, 0.0035), V2(R * 0.62, L * 0.09), V2(R * 0.88, L * 0.22),
                            V2(R, L * 0.42), V2(R * 0.97, L * 0.6), V2(R * 0.84, L * 0.76), V2(R * 0.56, L * 0.88),
                            V2(R * 0.26, L * 0.94), V2(R * 0.13, L * 0.975), V2(0, L)]
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
