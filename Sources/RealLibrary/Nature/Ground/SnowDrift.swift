import simd
import Foundation

/// Wind-built snow drift about 6 x 3 m and 0.45 m high: long gentle windward slope, steep lee face toward
/// +X, ragged footprint whose rim sinks below y = 0.
public struct SnowDrift: RealAsset {
    public static let id = "snow-drift"
    public static let summary = "Snow drift about 6 x 3 m, 0.45 m high: gentle windward slope, steep lee face, wind-carved surface, ragged sinking rim."
    public static let tags = ["nature", "ground", "snow"]
    public static let budget = 5_000
    public static let preview = PreviewHint(azimuth: 120, elevation: 18, distance: 0.9)

    /// Footprint half-extents in meters (X along the wind, Z across).
    public var extent = V2(3.0, 1.5)
    /// Crest height in meters.
    public var peak: Float = 0.45
    public var material: MaterialKey = "ground.snow"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        let ns = UInt32(truncatingIfNeeded: rng.next())
        let ex = V2(rng.vary(extent.x, 0.15), rng.vary(extent.y, 0.15)), h0 = rng.vary(peak, 0.2)
        func outline(_ a: Float) -> Float {
            let e = 1 / sqrt(pow(cos(a) / ex.x, 2) + pow(sin(a) / ex.y, 2))
            return e * (1 + 0.15 * Noise.fbm(V3(cos(a) * 1.4, sin(a) * 1.4, 2), octaves: 3, seed: ns))
        }
        let s = GroundMesh.disc(material: material, rings: 26, sectors: 72, outline: outline) { p, t in
            let xn = p.x / ex.x, zn = p.y / ex.y
            let crest: Float = 0.35 + 0.15 * zn * zn
            let up = smoothstep(-1.05, crest, xn)                    // windward ramp
            let down = 1 - smoothstep(crest, crest + 0.35, xn)      // lee face
            let across = pow(max(0, 1 - zn * zn), 0.7)
            let carve = Noise.ridged(V3(p.x * 0.8, 0, p.y * 3), octaves: 3, seed: ns &+ 2) * 0.012
            let y = h0 * pow(up, 1.6) * down * across + carve * up * down
            return y * GroundMesh.rim(t, from: 0.55) - smoothstep(0.85, 1, t) * 0.03
        }
        var surf = s
        surf.occlusion = surf.positions.map { 0.85 + 0.15 * smoothstep(0, h0 * 0.4, $0.y) }
        return LODModel(Model(name: Self.id, surfaces: [surf]))
    }
}
