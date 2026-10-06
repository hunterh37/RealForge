import simd
import Foundation

/// Standard rolled-rim terracotta pot, 0.42 m across the rim and 0.36 m tall: tapered wall 12 mm thick,
/// a 70 mm rim band, potting soil 4 cm below the rim, white salt bloom creeping up from the base.
public struct TerracottaPlanter: RealAsset {
    public static let id = "terracotta-planter"
    public static let summary = "Terracotta pot, 0.42 m rim: tapered wall with rolled rim band, soil fill, efflorescence near the base."
    public static let tags = ["prop", "landscaping", "garden", "outdoor", "ceramic", "container"]
    public static let budget = 3000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 30, elevation: 25)

    /// Rim diameter (m).
    public var rimDiameter: Float = 0.42
    /// Height (m).
    public var height: Float = 0.36
    /// Clay material.
    public var clay: MaterialKey = "ceramic.bisque:B4643E"
    /// Salt bloom near the base.
    public var bloom: MaterialKey = "ceramic.bisque:BF8F78"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let R = rimDiameter / 2, H = height, band: Float = 0.07, wall: Float = 0.012
        let rb = R * 0.68
        let outer: [V2] = [V2(0, 0.004), V2(rb - 0.01, 0), V2(rb, 0.006), V2(R - 0.025, H - band - 0.004), V2(R - 0.006, H - band),
                           V2(R, H - band + 0.008), V2(R, H - 0.006), V2(R - 0.004, H)]
        let inner: [V2] = [V2(R - wall - 0.006, H - 0.001), V2(R - wall - 0.008, H - band), V2(R - 0.025 - wall, H - band - 0.01),
                           V2(rb - wall, 0.02), V2(0, 0.02)]
        m.add(Prim.lathe(outer + inner, segments: 48, seamTile: 0.4, material: clay))
        // Bloom band near the base: thin lathe shell just outside the wall, fading up.
        let bloomH = rng.float(0.03...0.05)
        var shell = Prim.lathe((0...4).map { k -> V2 in
            let y = 0.008 + Float(k) / 4 * bloomH
            let r = rb + (R - 0.025 - rb) * (y / (H - band)) + 0.0006
            return V2(r, y)
        }, segments: 48, seamTile: 0.3, material: bloom)
        shell.deform { $0 }
        m.add(shell)
        // Soil with a slight mound.
        let sy = H - 0.04
        var soil = Prim.lathe([V2(R - wall - 0.01, sy - 0.004), V2(R * 0.5, sy + 0.006), V2(0, sy + 0.01)], segments: 40, seamTile: 0.3, material: "soil.potting")
        soil.displace { p, _ in 0.004 * sin(p.x * 60) * cos(p.z * 47) }
        m.add(soil)
        groundAO(&m, height: 0.08)
        return LODModel(m)
    }
}
