import simd
import Foundation

/// Barchan sand dune about 14 m across and 2.2 m high: long windward slope, sharp crest, 32 degree slip
/// face toward +X, horns curving downwind. Ragged base sinks below y = 0. 3 LODs.
public struct SandDune: RealAsset {
    public static let id = "sand-dune"
    public static let summary = "Barchan sand dune about 14 m across, 2.2 m high: windward slope, sharp crest, 32 degree slip face, downwind horns, 3 LODs."
    public static let tags = ["nature", "ground", "desert", "beach"]
    public static let budget = 18_000
    public static let preview = PreviewHint(azimuth: 230, elevation: 18, distance: 0.85)

    /// Crest height in meters.
    public var peak: Float = 2.2
    /// Half width across the wind in meters.
    public var halfWidth: Float = 5.5
    /// Windward slope length in meters.
    public var windward: Float = 6.5
    /// Disc radius of the sand footprint in meters.
    public var radius: Float = 8.5
    public var material: MaterialKey = "ground.sand"
    /// (rings, sectors) per LOD.
    public var detail: [(Int, Int)] = [(56, 128), (28, 64), (14, 32)]
    public var lodDistances: [Float] = [40, 100]
    public init() {}

    func height(_ p: V2, seed: UInt32) -> Float {
        let zn = p.y / halfWidth
        guard abs(zn) < 1 else { return 0 }
        let H = peak * (1 - zn * zn)
        let c: Float = 0.6 + 3.2 * zn * zn                    // crest bends downwind toward the horns
        let x0 = c - windward * (1 - 0.45 * zn * zn)
        let leeSlope: Float = 0.62                            // tan 32 degrees
        if p.x < x0 { return 0 }
        if p.x < c {
            let u = (p.x - x0) / (c - x0)
            return H * pow(sin(u * .pi / 2), 1.6)
        }
        return max(0, H - (p.x - c) * leeSlope)
    }

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        let ns = UInt32(truncatingIfNeeded: rng.next())
        let r0 = rng.vary(radius, 0.08)
        let phase = rng.float(0...6.28)
        func lod(_ d: (Int, Int)) -> Model {
            var s = GroundMesh.disc(material: material, rings: d.0, sectors: d.1,
                                    outline: { a in GroundMesh.outline(a + phase, radius: r0, wobble: 0.12, seed: ns) }) { p, t in
                let warp = V2(0, Noise.fbm(V3(p.x * 0.15, 0, 1), octaves: 2, seed: ns &+ 1) * 1.2)
                var y = height(p + warp, seed: ns)
                y += 0.05 + Noise.fbm(V3(p.x * 0.3, 0, p.y * 0.3), octaves: 3, seed: ns &+ 2) * 0.06
                return y * GroundMesh.rim(t, from: 0.7) - smoothstep(0.88, 1, t) * 0.04
            }
            s.occlusion = s.positions.map { 0.9 + 0.1 * smoothstep(0, 0.4, $0.y) }
            return Model(name: Self.id, surfaces: [s])
        }
        return LODModel(levels: detail.map(lod), switchDistances: Array(lodDistances.prefix(detail.count - 1)))
    }
}
