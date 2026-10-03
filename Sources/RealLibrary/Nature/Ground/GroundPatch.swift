import simd
import Foundation

/// Square terrain patch, 40 m by default, with eroded relief: smooth flanks, shallow gullies, detail in
/// the flats, and baked occlusion in hollows. UVs in meters for the ground material's tile size.
public struct GroundPatch: RealAsset {
    public static let id = "ground-patch"
    public static let summary = "Square heightfield terrain with eroded fBm relief, shallow gullies, baked hollow occlusion and forest-floor material."
    public static let tags = ["nature", "ground", "terrain"]
    public static let budget = 60_000
    public static let preview = PreviewHint(azimuth: 30, elevation: 32, distance: 0.8, ground: false, fog: 0)
    /// Side length in meters.
    public var size: Float = 40
    public var segments = 128
    /// Peak-to-trough relief scale in meters.
    public var relief: Float = 0.6
    /// Depth of the gullies cut by the ridged term, as a fraction of `relief`.
    public var gullies: Float = 0.35
    /// Feature size of the relief in meters (larger = broader hills).
    public var featureSize: Float = 12.5
    public var material: MaterialKey = "ground.forest"
    /// Keep the center flat (radius, meters) so props sit cleanly.
    public var flatCenter: Float = 3
    /// Strength of baked occlusion in hollows (0 = none).
    public var hollowShade: Float = 0.6
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var s = Prim.terrain(size: V2(size, size), segments: segments, material: material) { p in
            height(x: p.x, z: p.y, seed: seed) - edgeDrop(p)
        }
        if hollowShade > 0 { GroundMesh.shadeHollows(&s, gridSide: segments + 1, radius: max(2, segments / 24), relief: relief, strength: hollowShade) }
        return LODModel(Model(name: Self.id, surfaces: [s]))
    }

    func edgeDrop(_ p: V2) -> Float { smoothstep(size * 0.42, size * 0.5, max(abs(p.x), abs(p.y))) * 0.05 }

    /// Height before the flat-center mask.
    func rawHeight(_ p: V2, seed: UInt64) -> Float {
        let ns = UInt32(truncatingIfNeeded: seed)
        let f = 1 / max(featureSize, 0.5)
        let w = V2(Noise.perlin(V3(p.x * f * 0.5, 3.1, p.y * f * 0.5), seed: ns &+ 5),
                   Noise.perlin(V3(p.x * f * 0.5, 7.7, p.y * f * 0.5), seed: ns &+ 6)) * 0.6
        let q = p * f + w
        let base = GroundMesh.eroded(q, octaves: 6, seed: ns)
        let gully = Noise.ridged(V3(q.x * 0.7, 0, q.y * 0.7), octaves: 3, seed: ns &+ 9)
        return (base - gully * gullies + gullies * 0.4) * relief
    }

    /// Height at (x, z) matching the mesh (for placing instances on the ground).
    public func height(x: Float, z: Float, seed: UInt64) -> Float {
        let p = V2(x, z)
        return rawHeight(p, seed: seed) * smoothstep(flatCenter, flatCenter * 2.5, simd_length(p))
    }
}
