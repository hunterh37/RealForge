import simd
import Foundation

/// Sesame burger bun, 10.5 cm, sliced and closed: a glossy domed crown resting on the heel. Each half
/// is a closed crust shell with a crumb disc set into its cut face (`food.bun-crumb`), so lifting
/// the crown shows soft crumb on both faces. About 45 sesame seeds sit on the crown, each a small
/// flattened closed shell tilted to the dome. Cook kind `batter`: crumb toasts, crust darkens.
public struct BurgerBun: RealFood {
    public static let id = "burger-bun"
    public static let summary = "Sesame burger bun, 10.5 cm: glossy domed crown with sesame seeds over a heel, soft crumb inside; toasts."
    public static let tags = ["prop", "food", "kitchen", "handheld"]
    public static let budget = 7000
    public static let author = "realityhd"
    public static let kind = FoodKind.batter
    public static let preview = PreviewHint(azimuth: 30, elevation: 25, distance: 0.32, studio: true)

    /// Crown diameter (m).
    public var diameter: Float = 0.105
    /// Heel height (m).
    public var heelHeight: Float = 0.02
    /// Crown height (m).
    public var crownHeight: Float = 0.036
    /// Sesame seed count.
    public var seeds = 46
    /// Material keys.
    public var crustKey: MaterialKey = "food.bun-crust"
    public var crumb: MaterialKey = "food.bun-crumb"
    public var sesame: MaterialKey = "food.sesame"
    public init() {}

    public var coreCenter: V3 { V3(0, heelHeight, 0) }

    public func capMaterial(for key: MaterialKey) -> MaterialKey? {
        if key == crustKey || key == crumb { return crumb }
        if key == sesame { return sesame }
        return nil
    }

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        let R = diameter / 2, hH = heelHeight, cH = crownHeight
        let sd = UInt32(truncatingIfNeeded: seed)
        // Crown: flat base at y = 0 (local), rounded shoulder, dome.
        let crownTop: (Float) -> Float = { r in
            let x = min(1, r / R)
            return cH * pow(max(0, 1 - pow(x, 2.4)), 0.5)
        }
        let crownP: [V2] = [V2(0, 0.0004), V2(R * 0.55, 0.0002), V2(R * 0.9, 0.0008), V2(R * 0.985, cH * 0.12), V2(R, cH * 0.28),
                            V2(R * 0.96, cH * 0.5), V2(R * 0.84, cH * 0.75), V2(R * 0.6, cH * 0.93), V2(R * 0.3, cH * 0.99), V2(0, cH)]
        var crown = FoodMesh.revolve(edge: 0.0052, seamTile: 0.06, material: crustKey, curve: FoodMesh.profile(crownP))
        crown.displace { p, _ in RecipeMesh.noise(p, 40, seed: sd &+ 1) * 0.0007 }
        crown = FoodMesh.boxUV(crown)
        let heelR = R * 0.97
        let heelP: [V2] = [V2(0, 0), V2(heelR * 0.6, 0), V2(heelR * 0.88, 0.0005), V2(heelR * 0.97, hH * 0.15), V2(heelR, hH * 0.5),
                           V2(heelR * 0.985, hH * 0.85), V2(heelR * 0.95, hH * 0.99), V2(heelR * 0.6, hH), V2(0, hH)]
        var heel = FoodMesh.revolve(edge: 0.0058, seamTile: 0.06, material: crustKey, curve: FoodMesh.profile(heelP))
        heel.displace { p, n in n.y < -0.8 ? 0 : RecipeMesh.noise(p, 45, seed: sd &+ 2) * 0.0005 }
        heel = FoodMesh.boxUV(heel)
        // Crumb discs set into both cut faces.
        let disc: (Float) -> Surface = { r in
            RecipeMesh.slab(outline: RecipeMesh.loop(count: 128) { _ in r }, thickness: 0.003, bevel: 0.001, edge: 0.0055,
                            bevelSegments: 2, material: crumb)
        }
        var heelCrumb = disc(heelR * 0.92)
        heelCrumb.deform { p in V3(p.x, p.y + hH - 0.0027, p.z) }
        var crownCrumb = disc(R * 0.92)
        crownCrumb.deform { p in V3(p.x, p.y - 0.0003, p.z) }
        // Sesame seeds on the dome.
        var seedsS = Surface(material: sesame)
        var placed: [V2] = []
        var tries = 0
        while placed.count < seeds && tries < 4000 {
            tries += 1
            let rr = R * 0.8 * sqrt(rng.float()), a = rng.float(0...6.28)
            let p2 = V2(rr * cos(a), rr * sin(a))
            if placed.contains(where: { simd_distance($0, p2) < 0.0052 }) { continue }
            placed.append(p2)
            let y = crownTop(rr)
            let dy = (crownTop(rr + 0.001) - crownTop(max(0, rr - 0.001))) / 0.002
            let radial = rr > 1e-4 ? V3(cos(a), 0, sin(a)) : V3(1, 0, 0)
            let n = simd_normalize(V3(0, 1, 0) - radial * dy)
            var sh = FoodMesh.revolve(edge: 0.0013, seamTile: 0.01, material: sesame) { t in
                let q = Float.pi * t
                return V2(0.00095 * sin(q) * (1 - 0.25 * t), -0.0017 + 0.0034 * (0.5 - 0.5 * cos(q)))
            }
            // Flatten (local x thin), lay along the surface with a random yaw.
            sh.deform { q in V3(q.x * 0.45, q.y, q.z) }
            let yaw = rng.float(0...6.28)
            let t1 = simd_normalize(simd_cross(n, V3(cos(yaw), 0, sin(yaw))))
            let t2 = simd_cross(t1, n)
            let c = V3(p2.x, y + 0.00025, p2.y)
            sh.deform { q in c + t1 * q.y + n * q.x + t2 * q.z }
            seedsS.append(RecipeMesh.outward(sh))
        }
        var m = Model(name: Self.id)
        m.add(heel)
        m.add(heelCrumb)
        var top = Model(name: "crown")
        top.add(crown)
        top.add(crownCrumb)
        top.add(seedsS)
        m.add(top, Xform(translation: V3(0, hH + 0.0006, 0)))
        let b = m.bounds
        m = m.transformed(Xform(translation: V3(0, -b.min.y, 0)))
        groundAO(&m, height: 0.012, floor: 0.6)
        return LODModel(m)
    }
}
