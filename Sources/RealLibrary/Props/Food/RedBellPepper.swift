import simd
import Foundation

/// Red bell pepper standing on its four lobes. The body is one thick-walled closed shell (glossy skin
/// outside, the inner wall of the hollow cavity inside; cut face `food.pepper-flesh`, an annulus), a
/// white placenta hangs from the top of the cavity with pale seeds on it (cut face `food.pepper-pith`),
/// and a curved green stem rises from a lobed calyx in the shoulder dimple.
public struct RedBellPepper: RealFood {
    public static let id = "red-bell-pepper"
    public static let summary = "Red bell pepper, 9 cm: four-lobed glossy skin over a thick hollow wall, seeded white placenta, green stem and calyx."
    public static let tags = ["prop", "food", "kitchen", "handheld"]
    public static let budget = 8000
    public static let author = "realityhd"
    public static let kind = FoodKind.vegetable
    public static let preview = PreviewHint(azimuth: 30, elevation: 22, distance: 0.32, studio: true)

    /// Body diameter across the lobes (m).
    public var diameter: Float = 0.093
    /// Body height to the shoulders (m).
    public var height: Float = 0.083
    /// Wall thickness (m).
    public var wall: Float = 0.006
    /// Lobes (3 or 4).
    public var lobes = 4
    /// Seeds on the placenta.
    public var seeds = 34
    /// Material keys.
    public var skin: MaterialKey = "food.pepper-red"
    public var flesh: MaterialKey = "food.pepper-flesh"
    public var pith: MaterialKey = "food.pepper-pith"
    public var seed: MaterialKey = "food.pepper-pith:EEDFB0"
    public var stem: MaterialKey = "food.stem-green"
    public init() {}

    public var coreCenter: V3 { V3(0, height * 0.5, 0) }

    public func capMaterial(for key: MaterialKey) -> MaterialKey? {
        if key == skin { return flesh }
        if key == pith || key == seed { return pith }
        return nil
    }

    public func build(seed rngSeed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: rngSeed)
        let R = diameter / 2 / 1.06, H = height
        let profile: [V2] = [V2(0, H * 0.09), V2(R * 0.18, H * 0.05), V2(R * 0.42, H * 0.012), V2(R * 0.68, H * 0.04),
                             V2(R * 0.88, H * 0.15), V2(R * 0.98, H * 0.33), V2(R, H * 0.55), V2(R * 0.98, H * 0.74),
                             V2(R * 0.92, H * 0.88), V2(R * 0.76, H * 0.98), V2(R * 0.55, H * 1.01), V2(R * 0.36, H * 0.985),
                             V2(R * 0.22, H * 0.94), V2(R * 0.12, H * 0.915), V2(0, H * 0.91)]
        var outer = FoodMesh.revolve(edge: 0.0052, seamTile: 0.08, material: skin, curve: FoodMesh.profile(profile))
        let a0 = rng.float(0...6.28), nl = Float(max(3, lobes))
        let ph = (0..<4).map { _ in rng.float(0...6.28) }
        let lobeAmp = (0..<max(3, lobes)).map { _ in rng.float(0.85...1.15) }
        outer.deform { p in
            let a = atan2(p.z, p.x)
            let t = p.y / H
            let r = simd_length(V2(p.x, p.z))
            let rn = min(1, r / R)
            // Lobes: rounded bulges with creased valleys, strongest at the shoulders and the feet.
            let c = cos(nl * (a - a0))
            let lobe = pow(0.5 + 0.5 * c, 0.45)
            let idx = Int(((a - a0) / (2 * .pi / nl)).rounded()) % max(3, lobes)
            let amp = lobeAmp[(idx + max(3, lobes)) % max(3, lobes)]
            let k = 1 + (0.11 * (lobe - 0.66) * amp) * (0.6 + 0.4 * sin(.pi * t)) * rn + 0.012 * sin(a * 2 + ph[0] + t * 3)
            var q = V3(p.x * k, p.y, p.z * k)
            // Feet: the lobes reach lower at the base; valleys rise.
            let foot = (1 - smoothstep(0.0, 0.3, t)) * smoothstep(0.2, 0.7, rn)
            q.y -= H * 0.035 * (lobe - 0.45) * foot
            // Shoulders: valleys dip toward the stem dimple.
            let sh = smoothstep(0.75, 0.97, t) * smoothstep(0.25, 0.7, rn)
            q.y += H * 0.03 * (lobe - 0.55) * sh
            // Slight lean and waviness.
            q.x += 0.002 * t * t * cos(ph[1]); q.z += 0.002 * t * t * sin(ph[1])
            q += V3(0, 0.0007 * sin(a * 5 + ph[2]) * sin(.pi * t), 0)
            return q
        }
        let body = FoodMesh.hollow(outer, wall: wall)
        var m = Model(name: Self.id)
        m.add(body)
        // Placenta: a lobed white mass hanging from the cavity roof, seeds clustered on its lower half.
        let topIn = H * 0.91 - wall
        let pithProfile: [V2] = [V2(0, topIn - H * 0.36), V2(R * 0.12, topIn - H * 0.34), V2(R * 0.2, topIn - H * 0.27),
                                 V2(R * 0.24, topIn - H * 0.17), V2(R * 0.28, topIn - H * 0.06), V2(R * 0.33, topIn + 0.002),
                                 V2(R * 0.18, topIn + 0.004), V2(0, topIn + 0.004)]
        var pl = FoodMesh.revolve(edge: 0.0042, seamTile: 0.03, material: pith, curve: FoodMesh.profile(pithProfile))
        pl.deform { p in
            let a = atan2(p.z, p.x)
            let k = 1 + 0.22 * pow(0.5 + 0.5 * cos(nl * (a - a0)), 2) - 0.1
            return V3(p.x * k, p.y, p.z * k)
        }
        m.add(pl)
        // Seeds: flat discs lying on the placenta, edge-on toward the surface normal.
        let pn = pl.positions.indices.filter { pl.positions[$0].y < topIn - H * 0.05 && pl.positions[$0].y > topIn - H * 0.32 }
        var seedS = Surface(material: seed)
        for i in 0..<seeds where !pn.isEmpty {
            var r = rng.fork(100 + i)
            let vi = r.pick(pn)
            let n = pl.normals[vi], p = pl.positions[vi]
            let sr = r.float(0.0016...0.0021)
            var disc = FoodMesh.revolve(edge: 0.0016, seamTile: 0.01, material: seed) { t in
                V2(sr * sin(.pi * t) * (1 - 0.15 * t), -0.0003 * cos(.pi * t))
            }
            // Comma shape: a notch on one side.
            disc.deform { q in V3(q.x * (1 - 0.25 * smoothstep(0.6, 1, q.x / sr)), q.y, q.z) }
            let tilt = simd_quatf(from: .up, to: simd_normalize(simd_cross(n, r.unitVector()) + n * 0.3))
            seedS.append(disc, Xform(translation: p + n * 0.0005, rotation: tilt))
        }
        m.add(seedS)
        // Calyx: a flattened lobed cap in the shoulder dimple; stem: a curved closed tube cut flat.
        let topY = H * 0.915
        var calyx = FoodMesh.revolve(edge: 0.0022, seamTile: 0.02, material: stem) { t in
            let a = Float.pi * t
            return V2(0.0115 * sin(a), topY + 0.0022 - 0.0034 * cos(a))
        }
        calyx.deform { p in
            let a = atan2(p.z, p.x)
            let k = 1 + 0.18 * cos(5 * a + ph[3])
            return V3(p.x * k, p.y, p.z * k)
        }
        m.add(calyx)
        let lean = rng.float(0...6.28), sl: Float = 0.019
        let stemPath = catmull([V3(0, topY, 0), V3(0.001 * cos(lean), topY + sl * 0.45, 0.001 * sin(lean)),
                                V3(0.006 * cos(lean), topY + sl * 0.85, 0.006 * sin(lean)), V3(0.011 * cos(lean), topY + sl, 0.011 * sin(lean))], per: 3)
        let sr0: Float = 0.0052
        m.add(FoodMesh.tube(stemPath, radii: stemPath.indices.map { i in
            let t = Float(i) / Float(stemPath.count - 1)
            return sr0 * (1.25 - 0.45 * smoothstep(0, 0.4, t))
        }, sides: 10, endBulge: 0.08, material: stem))
        let bb = m.bounds
        m = m.transformed(Xform(translation: V3(0, -bb.min.y, 0)))
        groundAO(&m, height: 0.02, floor: 0.55)
        return LODModel(m)
    }
}
