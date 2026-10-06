import simd
import Foundation

/// Classic 25 cm terracotta flower pot on its saucer: tapered thrown body,
/// thick rolled rim band, raised foot ring, potting soil filled to just below the rim. Seeds vary the
/// taper, the ridge phase and the soil surface.
public struct TerracottaPot: RealAsset {
    public static let id = "terracotta-pot"
    public static let summary = "Classic 25 cm terracotta flower pot: tapered thrown body, rolled rim band, drainage foot, matching saucer, filled with potting soil."
    public static let tags = ["prop", "garden", "ceramic", "decor"]
    public static let budget = 8000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 24, elevation: 18, distance: 0.8, studio: true)

    /// Fired clay for pot and saucer.
    public var clay: MaterialKey = "ceramic.bisque:B4643C"
    /// Saucer clay, slightly darker (damp).
    public var saucerClay: MaterialKey = "ceramic.bisque:9C5333"
    public var soil: MaterialKey = "soil.potting"
    /// Rim outer radius (m).
    public var rimRadius: Float = 0.128
    /// Pot height above the saucer (m).
    public var height: Float = 0.22
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let R = rimRadius, H = height
        let foot = R * rng.vary(0.7, 0.03)
        let sy: Float = 0.014                          // pot sits in the saucer
        // Saucer: flat bottom, sloped wall, rounded lip.
        let SR = R * 1.17
        m.add(turned([(0, 0.004), (SR * 0.8, 0.004), (SR * 0.82, 0), (SR * 0.9, 0.001), (SR - 0.004, 0.022), (SR, 0.026),
                      (SR - 0.006, 0.028), (SR - 0.01, 0.024), (SR * 0.86, 0.01), (0, 0.01)], segments: 56, material: saucerClay))
        // Body: foot ring, taper with a waist at the band, band, inner wall down to the soil.
        let band = H - 0.042
        var prof: [(Float, Float)] = [(0, sy + 0.006), (foot - 0.012, sy + 0.006), (foot - 0.01, sy), (foot, sy + 0.002)]
        for i in 1...16 {
            let t = Float(i) / 16
            let r = foot + (R - 0.012 - foot) * t
            prof.append((r, sy + 0.004 + (band - sy - 0.004) * t))
        }
        prof += [(R - 0.004, band + 0.002), (R, band + 0.006), (R, H - 0.004), (R - 0.004, H),
                 (R - 0.012, H), (R - 0.016, H - 0.006), (R - 0.02, H - 0.05), (foot - 0.018, sy + 0.02), (0, sy + 0.02)]
                // Story detail: one chipped notch out of the rim lip.
        var body = turned(prof, segments: 96, material: clay)
        let chipA = rng.float(0...(2 * Float.pi))
        body.deform { p in
            guard p.y > H - 0.012 else { return p }
            var d = atan2(p.z, p.x) - chipA
            d = atan2(sin(d), cos(d))
            let w = max(0, 1 - abs(d) / 0.16) * smoothstep(H - 0.012, H, p.y)
            return p - V3(0, 0.008 * w * w, 0)
        }
        m.add(body)
        // Soil: domed, lumpy disc closing the inner wall.
        let soilY = H - rng.vary(0.03, 0.006)
        var disc = Prim.lathe([V2(R - 0.021, H - 0.05), V2(R - 0.019, soilY), V2((R - 0.02) * 0.6, soilY + 0.004), V2(0, soilY + 0.006)],
                              segments: 48, material: soil)
        disc.displace { p, _ in 0.003 * Noise.fbm(V3(p.x * 40, 0, p.z * 40), octaves: 3) }
        disc.uvs = disc.positions.map { V2($0.x, $0.z) }       // planar meters, no radial pinch
        disc.computeTangents()
        m.add(disc)
        groundAO(&m)
        return LODModel(m)
    }
}
