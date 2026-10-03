import simd
import Foundation

/// Rain puddle about 1.4 m across: a shallow mud hollow (floor at y = 0, rim 2 cm up), filled with a flat
/// muddy-water surface. The mud rim sinks below y = 0 at its outer edge to blend into the ground.
public struct Puddle: RealAsset {
    public static let id = "puddle"
    public static let summary = "Rain puddle about 1.4 m across: shallow mud hollow with a low rim and a flat, near-mirror muddy water surface."
    public static let tags = ["nature", "ground", "water"]
    public static let budget = 4_000
    public static let preview = PreviewHint(azimuth: 25, elevation: 22, distance: 0.9)

    /// Mean water radius in meters.
    public var radius: Float = 0.7
    /// Water depth at the center in meters (the hollow floor sits near y = 0).
    public var depth: Float = 0.012
    /// Outline irregularity (0 = circle).
    public var wobble: Float = 0.35
    public var mudMaterial: MaterialKey = "ground.mud"
    /// Transparent muddy water with Fresnel opacity; `ground.puddle` gives an opaque look.
    public var waterMaterial: MaterialKey = "water.puddle"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        let ns = UInt32(truncatingIfNeeded: rng.next())
        let r0 = rng.vary(radius, 0.2)
        let stretch = rng.float(0.7...1.0)
        func waterR(_ a: Float) -> Float {
            GroundMesh.outline(a, radius: r0, wobble: wobble, seed: ns) / sqrt(cos(a) * cos(a) + sin(a) * sin(a) / (stretch * stretch))
        }
        let lift: Float = 0.012
        let level = lift - depth * 0.25
        var mud = GroundMesh.disc(material: mudMaterial, rings: 22, sectors: 56, outline: { waterR($0) * 1.8 }) { p, t in
            let a = atan2(p.y, p.x), rn = simd_length(p) / waterR(a)
            var y = lift - depth * (1 - smoothstep(0, 1.1, rn))
            y += 0.009 * exp(-pow((rn - 1.18) / 0.18, 2))
            y += Noise.fbm(V3(p.x * 6, 0, p.y * 6), octaves: 3, seed: ns &+ 1) * 0.004
            return y - smoothstep(0.72, 1, t) * (lift + 0.035)
        }
        mud.occlusion = mud.positions.map { 0.75 + 0.25 * smoothstep(lift - depth, lift, $0.y) }
        var water = GroundMesh.disc(material: waterMaterial, rings: 6, sectors: 56, outline: { waterR($0) * 1.12 }) { _, _ in level }
        // Shallowness for transparent water: 1 at the waterline, easing to 0.45 over the deepest mud.
        water.paintSplat { p in
            let a = atan2(p.z, p.x), rn = simd_length(V2(p.x, p.z)) / waterR(a)
            return 0.45 + 0.55 * smoothstep(0.35, 1.05, rn)
        }
        return LODModel(Model(name: Self.id, surfaces: [mud, water]))
    }
}
