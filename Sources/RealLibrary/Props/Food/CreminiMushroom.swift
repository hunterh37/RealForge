import simd
import Foundation

/// Cremini (baby bella) mushroom standing on its stem: a brown domed cap with a slightly in-rolled
/// margin, a dark gill layer under it (its own closed shell, radial gills from the UV ridges in
/// `food.mushroom-gills`), and a stout white stem with a trimmed base. Cut vertically, the cap and
/// stem cap with `food.mushroom-flesh` and the gill layer shows as a dark band under the cap.
public struct CreminiMushroom: RealFood {
    public static let id = "cremini-mushroom"
    public static let summary = "Cremini mushroom, 4.8 cm cap: brown domed cap, dark gills under a rolled margin, stout white stem; browns when cooked."
    public static let tags = ["prop", "food", "kitchen", "handheld"]
    public static let budget = 6000
    public static let author = "realityhd"
    public static let kind = FoodKind.vegetable
    public static let preview = PreviewHint(azimuth: 30, elevation: 20, distance: 0.18, studio: true)

    /// Cap diameter (m).
    public var capDiameter: Float = 0.048
    /// Cap height (m).
    public var capHeight: Float = 0.022
    /// Stem height below the gills (m).
    public var stemHeight: Float = 0.015
    /// Stem radius (m).
    public var stemRadius: Float = 0.0078
    /// Material keys.
    public var cap: MaterialKey = "food.mushroom-cap"
    public var flesh: MaterialKey = "food.mushroom-flesh"
    public var gills: MaterialKey = "food.mushroom-gills"
    public init() {}

    public var coreCenter: V3 { V3(0, stemHeight + capHeight * 0.4, 0) }

    public func capMaterial(for key: MaterialKey) -> MaterialKey? {
        switch key {
        case cap, flesh: return flesh
        case gills: return gills
        default: return nil
        }
    }

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        let Rc = capDiameter / 2, Hc = capHeight, yb = stemHeight
        let sd = UInt32(truncatingIfNeeded: seed)
        let capP: [V2] = [V2(0, yb + 0.0045), V2(Rc * 0.45, yb + 0.003), V2(Rc * 0.8, yb + 0.0012), V2(Rc * 0.93, yb + 0.0006),
                          V2(Rc * 0.985, yb + 0.002), V2(Rc, yb + Hc * 0.24), V2(Rc * 0.96, yb + Hc * 0.5), V2(Rc * 0.84, yb + Hc * 0.76),
                          V2(Rc * 0.6, yb + Hc * 0.93), V2(Rc * 0.3, yb + Hc * 0.995), V2(0, yb + Hc)]
        var capS = FoodMesh.revolve(edge: 0.0021, seamTile: 0.05, material: cap, curve: FoodMesh.profile(capP))
        let ph = (0..<3).map { _ in rng.float(0...6.28) }
        let tilt = rng.float(-0.06...0.06)
        let shape: (V3) -> V3 = { p in
            let a = atan2(p.z, p.x)
            let k = 1 + 0.025 * sin(a * 2 + ph[0]) + 0.012 * sin(a * 5 + ph[1])
            var q = V3(p.x * k, p.y, p.z * k)
            q.y += tilt * q.x
            return q
        }
        capS.deform(shape)
        capS.displace { p, n in n.y > 0.3 ? RecipeMesh.noise(p, 120, seed: sd) * 0.00025 : 0 }
        // Gill layer: a thin lens just inside the margin, u around = radial gill lines.
        let gr = Rc * 0.9
        var gillS = FoodMesh.revolve(edge: 0.002, seamTile: 0.08, material: gills) { t in
            let a = Float.pi * t
            return V2(gr * sin(a), yb + 0.0018 - 0.0019 * cos(a) + 0.0006 * sin(a))
        }
        gillS.deform(shape)
        // Stem: slightly flared trimmed base, narrowing into the cap.
        let sr = stemRadius
        let stemP: [V2] = [V2(0, 0), V2(sr * 0.8, 0), V2(sr * 1.08, 0.0012), V2(sr * 1.05, yb * 0.4), V2(sr * 0.96, yb * 0.85),
                           V2(sr * 0.98, yb + 0.002), V2(sr * 0.7, yb + 0.0045), V2(0, yb + 0.005)]
        var stemS = FoodMesh.revolve(edge: 0.002, seamTile: 0.03, material: flesh, curve: FoodMesh.profile(stemP))
        stemS.deform { p in
            var q = p
            q.x += 0.0006 * sin(p.y * 200 + ph[2]) * (p.y / yb)
            q.y += tilt * q.x * min(1, p.y / yb)
            return q
        }
        var m = Model(name: Self.id)
        m.add(capS)
        m.add(gillS)
        m.add(stemS)
        let b = m.bounds
        m = m.transformed(Xform(translation: V3(-(b.min.x + b.max.x) / 2, -b.min.y, -(b.min.z + b.max.z) / 2)))
        groundAO(&m, height: 0.01, floor: 0.6)
        return LODModel(m)
    }
}
