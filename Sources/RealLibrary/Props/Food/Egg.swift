import simd
import Foundation

/// Large brown hen egg lying on its side along +X (blunt end -X, pointed end +X). Nested closed
/// shells: the speckled calcite shell (uncapped; cracking is the cook interaction), the raw albumen
/// as a thick shell around the yolk cavity (cut face `food.egg-white`, transparent) and the yolk as a
/// solid sphere riding toward the blunt end (cut face `food.egg-yolk`).
public struct Egg: RealFood {
    public static let id = "egg"
    public static let summary = "Large brown hen egg, 5.8 cm: speckled matte shell over raw albumen and a centered yolk."
    public static let tags = ["prop", "food", "kitchen", "handheld"]
    public static let budget = 6000
    public static let author = "realityhd"
    public static let kind = FoodKind.egg
    public static let preview = PreviewHint(azimuth: 30, elevation: 25, distance: 0.2, studio: true)

    /// Length (m).
    public var length: Float = 0.058
    /// Diameter (m).
    public var diameter: Float = 0.044
    /// Yolk diameter (m).
    public var yolk: Float = 0.03
    /// Material keys.
    public var shell: MaterialKey = "food.egg-shell"
    public var white: MaterialKey = "food.egg-white"
    public var yolkKey: MaterialKey = "food.egg-yolk"
    public init() {}

    var yolkX: Float { -length * 0.06 }
    public var coreCenter: V3 { V3(yolkX, diameter / 2, 0) }

    public func capMaterial(for key: MaterialKey) -> MaterialKey? {
        if key == white { return white }
        if key == yolkKey { return yolkKey }
        return nil
    }

    /// Egg outline: radius at height y (0...L, blunt end at 0).
    func eggCurve(_ t: Float, inset: Float) -> V2 {
        let L = length, R = diameter / 2 / 1.07
        let a = Float.pi * t
        let y = L * (0.5 - 0.5 * cos(a))
        let u = 2 * y / L - 1
        let r = R * sin(a) * (1 - 0.13 * u) * (1 + 0.06 * (1 - u * u))
        return V2(max(0, r - inset * sin(a)), y + inset * cos(a))
    }

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        let L = length
        var sh = FoodMesh.revolve(edge: 0.0031, seamTile: 0.05, material: shell) { eggCurve($0, inset: 0) }
        let ph = rng.float(0...6.28)
        sh.deform { p in
            let a = atan2(p.z, p.x)
            let k = 1 + 0.004 * sin(a * 3 + ph) * sin(.pi * p.y / L)
            return V3(p.x * k, p.y, p.z * k)
        }
        let whiteOuter = FoodMesh.revolve(edge: 0.004, seamTile: 0.05, material: white) { eggCurve($0, inset: 0.0006) }
        let yc = L / 2 + yolkX   // build axis: blunt end at y = 0
        let yr = yolk / 2
        let yolkS = FoodMesh.revolve(edge: 0.0034, seamTile: 0.03, material: yolkKey) { t in
            let a = Float.pi * t
            return V2(yr * sin(a), yc - yr * cos(a))
        }
        var whiteS = whiteOuter
        whiteS.append(yolkS.flipped().with(material: white))
        var m = Model(name: Self.id)
        m.add(FoodMesh.layAlongX(sh))
        m.add(FoodMesh.layAlongX(whiteS))
        m.add(FoodMesh.layAlongX(yolkS))
        // Blunt end at x = 0 after laying; center on X and rest the widest point on the ground.
        let bb = m.bounds
        m = m.transformed(Xform(translation: V3(-L / 2, -bb.min.y, 0)))
        groundAO(&m, height: 0.01, floor: 0.6)
        return LODModel(m)
    }
}
