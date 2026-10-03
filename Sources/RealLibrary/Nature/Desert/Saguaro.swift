import simd
import Foundation

/// Saguaro (Carnegiea gigantea), ~7 m: ribbed column 45 cm across with 18 ribs, 1-4 arms that leave
/// at 2.5-4.5 m, bend out through an elbow and rise parallel to the trunk; domed tips, spine rows on
/// the rib crests, a corky grey-brown base.
public struct Saguaro: RealAsset {
    public static let id = "saguaro"
    public static let summary = "Saguaro, ~7 m: 18-rib column with 1-4 elbowed arms, domed tips, spine rows on rib crests, corky base, 3 LODs."
    public static let tags = ["nature", "desert"]
    public static let budget = 26_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 30, elevation: 8, distance: 1.1)

    /// Trunk height in meters.
    public var height: Float = 7
    /// Trunk radius to the rib crests, meters.
    public var radius: Float = 0.24
    public var ribs = 18
    public var armRibs = 14
    public var armCount: ClosedRange<Int> = 1...4
    /// Height of the corky base, meters.
    public var corkHeight: Float = 0.5
    public var lodDistances: [Float] = [15, 40]
    public init() {}

    private struct Stem { var points: [V3]; var radius: Float; var neck: Bool; var ribs: Int }

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        let h = rng.vary(height, 0.15)
        let R = rng.vary(radius, 0.08)
        let ns = UInt32(truncatingIfNeeded: seed)
        // Trunk: nearly straight, slight wander.
        let lean = rng.unitVector() * 0.02
        var trunk: [V3] = []
        for k in 0...12 {
            let t = Float(k) / 12
            let w = V3(Noise.perlin(V3(t * 2, 0.5, 0), seed: ns), 0, Noise.perlin(V3(t * 2, 3.5, 0), seed: ns)) * 0.06
            trunk.append(V3(lean.x * t * h, -0.12 + (h + 0.12) * t, lean.z * t * h) + w * t)
        }
        var stems = [Stem(points: trunk, radius: R, neck: false, ribs: ribs)]
        // Arms.
        let na = rng.int(armCount)
        var az = rng.float(0...(2 * .pi))
        for _ in 0..<na {
            az += rng.float(1.4...2.6)
            let dir = V3(cos(az), 0, sin(az))
            let y0 = rng.float(0.36...0.62) * h
            let ar = R * rng.float(0.62...0.78)
            let out = rng.float(0.32...0.55), rise = rng.float(0.25...0.4)
            let len = min(h - y0 - 0.2, rng.float(1.1...2.6)) * (y0 > 0.55 * h ? 0.75 : 1)
            let p0 = V3(0, y0, 0) + dir * R * 0.2
            let p1 = p0 + dir * (R * 0.8 + out * 0.6) + V3(0, 0.04, 0)
            let p2 = p1 + dir * out * 0.45 + V3(0, rise * 0.6, 0)
            let p3 = p2 + dir * 0.06 + V3(0, rise, 0)
            let p4 = p3 + dir * rng.float(-0.05...0.12) + V3(0, max(0.3, len), 0)
            stems.append(Stem(points: catmull([p0, p1, p2, p3, p4], per: 8), radius: ar, neck: true, ribs: armRibs))
        }

        func level(_ lod: Int) -> Model {
            let perRib = [4, 2, 1][lod], spacing: Float = [0.1, 0.22, 0.5][lod]
            var body = Surface(material: "cactus.saguaro")
            for st in stems {
                let pts = CactusMesh.resample(catmull(st.points, per: st.neck ? 1 : 4), spacing: spacing)
                let acc = CactusMesh.arcLengths(pts), len = acc.last ?? 1
                let radii: [Float] = acc.map { s in
                    var r = st.radius * CactusMesh.dome(s, len: len, r: st.radius * 1.3)
                    if st.neck { r *= 0.72 + 0.28 * smoothstep(0, 0.35, s) }         // arms are pinched where they join
                    else { r *= 0.9 + 0.1 * smoothstep(0, 1.2, s) }                   // trunk slightly narrower at the ground
                    return r
                }
                let depth: Float = [0.1, 0.1, 0.04][lod]
                var surf = CactusMesh.ribbed(pts, radii: radii, ribs: st.ribs, depth: depth, perRib: perRib, tile: 0.25, material: "cactus.saguaro",
                                             weights: pts.map { 0.02 * saturate($0.y / h) })
                surf.bakeCavityAO(strength: 1.2, floor: 0.45)
                surf.occlusion = zip(surf.occlusion, surf.positions).map { o, p in o * (0.55 + 0.45 * smoothstep(-0.1, 1.0, p.y)) }
                body.append(surf)
            }
            body.computeTangents()
            var m = Model(name: Self.id, surfaces: [body])
            // Corky base: ragged boundary.
            let ch = corkHeight
            ConiferBuild.splitSurface(&m, "cactus.saguaro", into: "cactus.saguaro-cork") { c in
                c.y < ch + Noise.fbm(V3(c.x * 6, c.y * 2, c.z * 6), octaves: 3, seed: ns) * 0.35 && simd_length(V2(c.x, c.z)) < R * 1.5
            }
            return m
        }
        return LODModel(levels: [level(0), level(1), level(2)], switchDistances: lodDistances)
    }
}
