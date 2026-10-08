import simd
import Foundation

/// Three-tier cast-stone plaza fountain: a 4 m round basin with a molded coping and a water
/// surface, a turned pedestal carrying three scalloped bowls of shrinking size, a pineapple finial,
/// and sheets of water sheets falling from each bowl lip. Algae stains darken the waterline and the lips.
public struct PlazaFountain: RealAsset {
    public static let id = "plaza-fountain"
    public static let summary = "Three-tier cast-stone plaza fountain in a round 4 m basin with water."
    public static let tags = ["prop", "city", "street", "urban", "outdoor", "stone", "water", "decor"]
    public static let budget = 15000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 30, elevation: 15, distance: 1.0)

    /// Basin outer radius (m).
    public var basinRadius: Float = 2.0
    /// Total height (m).
    public var height: Float = 2.6
    /// Tier bowl radii, top last (m).
    public var tiers: [Float] = [0.95, 0.6, 0.35]
    /// Materials.
    public var stone: MaterialKey = "stone.cap"
    public var stained: MaterialKey = "stone.wall-block"
    public var water: MaterialKey = "water.fountain"
    public var stream: MaterialKey = "water.fountain-foam"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let R = basinRadius, wallH: Float = 0.45
        // Basin wall with a rounded coping, inner wall and floor.
        var prof: [V2] = [V2(R - 0.25, 0.05), V2(R - 0.25, wallH - 0.06)]
        for k in 0...6 { let a = Float.pi - Float.pi * Float(k) / 6; prof.append(V2(R - 0.125 + 0.14 * cos(a), wallH - 0.06 + 0.06 * sin(a))) }
        prof += [V2(R + 0.015, wallH - 0.08), V2(R, wallH - 0.12), V2(R, 0.04), V2(R + 0.04, 0.0)]
        m.add(Prim.lathe(prof.reversed(), segments: 48, seamTile: 0.6, material: stone))
        m.add(Prim.cylinder(radius: R - 0.24, height: 0.05, bevel: 0.01, segments: 48, material: stained))
        // Water in the basin, with an algae ring at the waterline.
        let wy = wallH - 0.12
        m.add(Prim.cylinder(radius: R - 0.252, height: 0.004, bevel: 0.001, segments: 48, material: water), Xform(translation: V3(0, wy, 0)))
        m.add(Prim.lathe([V2(R - 0.252, wy - 0.06), V2(R - 0.251, wy + 0.02)], segments: 64, seamTile: 0.6, material: "stone.wall-block:4E5236"))
        // Pedestal: turned shaft rising through the tiers.
        let ys: [Float] = [1.05, 1.75, 2.3]
        m.add(turned([(0, 0.05), (0.4, 0.05), (0.4, 0.15), (0.3, 0.22), (0.24, 0.4), (0.18, 0.7), (0.22, ys[0] - 0.2), (0.12, ys[0] - 0.1), (0, ys[0] - 0.1)], segments: 32, material: stone))
        for (i, r) in tiers.enumerated() {
            let y = ys[i]
            // Bowl: lip with a scalloped edge (lobes as radius ripple), shallow dish.
            var bowl: [V2] = [V2(0, y - 0.25), V2(r * 0.25, y - 0.22), V2(r * 0.7, y - 0.12), V2(r, y - 0.02), V2(r + 0.03, y + 0.03), V2(r, y + 0.06), V2(r - 0.05, y + 0.02), V2(r * 0.4, y - 0.05), V2(0, y - 0.06)]
            bowl = bowl.reversed()
            var s = Prim.lathe(bowl, segments: 40, seamTile: 0.6, material: i == 0 ? stained : stone)
            for v in s.positions.indices {
                let p = s.positions[v], rr = simd_length(V2(p.x, p.z))
                guard rr > r * 0.8 else { continue }
                let a = atan2(p.z, p.x), k = 1 + 0.035 * cos(a * 12)
                s.positions[v] = V3(p.x * k, p.y, p.z * k)
            }
            s.recomputeNormals(); s.computeTangents()
            m.add(s)
            m.add(Prim.cylinder(radius: r - 0.06, height: 0.004, bevel: 0.001, segments: 32, material: water), Xform(translation: V3(0, y + 0.0, 0)))
            // Falling water: streams from each scallop lobe arcing out and down to the tier below.
            let below = i == 0 ? wy : ys[i - 1]
            // Thin curtain sheet falling from the scalloped lip, flaring out as it drops.
            let r0 = r * 1.035 + 0.03, drop = y - below
            let curtain = (0...6).map { j -> V2 in let t = Float(j) / 6; return V2(r0 + 0.12 * t + 0.05 * t * t, y + 0.03 - drop * t * t) }
            // Split into one spill per scallop lobe (12), each narrowing as it falls, with gaps between.
            var sheet = Surface(material: stream)
            for k in 0..<12 {
                let ac = Float(k) / 12 * 2 * .pi + .pi / 12 * 0 , half0: Float = 0.2, base = UInt32(sheet.positions.count)
                for (j, c) in curtain.enumerated() {
                    let t = Float(j) / 6, half = half0 * (1 - 0.45 * t) * (1 + rng.float(-0.08...0.08))
                    for e: Float in [-1, 1] {
                        let a = ac + e * half
                        let p = V3(cos(a) * c.x, c.y, sin(a) * c.x)
                        _ = sheet.add(p, V3(cos(a), 0.2, sin(a)).normalized, V2(e * half * c.x, c.y))
                    }
                }
                for j in 0..<6 { let a = base + UInt32(j * 2); sheet.quad(a, a + 2, a + 3, a + 1) }
            }
            sheet.computeTangents()
            m.add(sheet)
            // Ripple ring where the streams land.
            m.add(Prim.torus(major: r * 1.035 + 0.2, minor: 0.012, segments: 40, sides: 4, minorY: 0.004, material: "water.fountain-foam"), Xform(translation: V3(0, below + 0.004, 0)))
            // Shaft segment above this bowl.
            if i < tiers.count - 1 {
                let y1 = ys[i + 1]
                m.add(turned([(0, y - 0.06), (0.14, y - 0.06), (0.1, y + 0.08), (0.08, (y + y1) / 2), (0.1, y1 - 0.22), (0.07, y1 - 0.1), (0, y1 - 0.1)], segments: 24, material: stone))
            }
        }
        // Pineapple finial with a spout.
        let fy = ys[2]
        m.add(turned([(0, fy - 0.06), (0.08, fy - 0.06), (0.06, fy + 0.02), (0.09, fy + 0.1), (0.08, fy + 0.2), (0.04, fy + 0.26), (0.015, height - 0.02), (0, height)], segments: 20, material: stone))
        // Coins on the basin floor.
        for _ in 0..<14 {
            let p = rng.inDisc(radius: R - 0.5)
            m.add(Prim.cylinder(radius: 0.011, height: 0.002, bevel: 0.0005, segments: 8, material: rng.chance(0.7) ? "metal.copper-patina" : "metal.steel"), Xform(translation: V3(p.x, 0.051, p.y)))
        }
        groundAO(&m, height: 0.3, floor: 0.6)
        return LODModel(m)
    }
}
