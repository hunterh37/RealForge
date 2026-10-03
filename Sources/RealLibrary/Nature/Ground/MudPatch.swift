import simd
import Foundation

/// Trampled mud patch about 5 m across: lumpy wet ground with 2 to 4 water-filled hollows. The rim sinks
/// below y = 0 so the patch blends into surrounding ground.
public struct MudPatch: RealAsset {
    public static let id = "mud-patch"
    public static let summary = "Trampled mud patch about 5 m across: lumpy wet ground, boot prints, and two to four shallow water-filled hollows."
    public static let tags = ["nature", "ground", "farm", "water"]
    public static let budget = 8_000
    public static let preview = PreviewHint(azimuth: 30, elevation: 24, distance: 0.85)

    /// Mean radius in meters.
    public var radius: Float = 2.5
    /// Lump height in meters.
    public var lumps: Float = 0.03
    public var hollows: ClosedRange<Int> = 2...4
    public var material: MaterialKey = "ground.mud"
    public var waterMaterial: MaterialKey = "ground.puddle"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        let ns = UInt32(truncatingIfNeeded: rng.next())
        let r0 = rng.vary(radius, 0.15)
        var dips: [(c: V2, r: Float)] = []
        for _ in 0..<rng.int(hollows) {
            dips.append((rng.inDisc(radius: r0 * 0.5), rng.float(0.35...0.8)))
        }
        func base(_ p: V2) -> Float { 0.034 + lumps * 0.5 * Noise.fbm(V3(p.x * 1.4, 0, p.y * 1.4), octaves: 4, seed: ns) }
        let dipDepth: Float = 0.032
        var mud = GroundMesh.disc(material: material, rings: 34, sectors: 96,
                                  outline: { GroundMesh.outline($0, radius: r0, wobble: 0.25, seed: ns &+ 1) }) { p, t in
            var y = base(p)
            for d in dips {
                let rn = simd_distance(p, d.c) / d.r
                y -= dipDepth * (1 - smoothstep(0, 1.15, rn))
            }
            return y * GroundMesh.rim(t, from: 0.6) - smoothstep(0.8, 1, t) * 0.03
        }
        mud.occlusion = mud.positions.map { 0.7 + 0.3 * smoothstep(0, 0.03, $0.y) }
        var m = Model(name: Self.id, surfaces: [mud])
        for d in dips {
            // Water a little below the surrounding ground; the mud hides the disc's outer part.
            let level = base(d.c) - dipDepth * 0.55
            let w = GroundMesh.disc(material: waterMaterial, rings: 2, sectors: 40, outline: { _ in d.r * 1.2 }) { _, _ in level }
            m.add(w, Xform(translation: V3(d.c.x, 0, d.c.y)))
        }
        return LODModel(m)
    }
}
