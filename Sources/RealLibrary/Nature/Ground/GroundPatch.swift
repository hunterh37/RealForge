import simd
import Foundation

/// Terrain patch with gentle relief. UVs in meters for the ground material's tile size.
public struct GroundPatch: RealAsset {
    public static let id = "ground-patch"
    public static let summary = "Square heightfield terrain with fBm relief and forest-floor material."
    public static let tags = ["nature", "ground", "terrain"]
    public static let budget = 60_000
    public static let preview = PreviewHint(azimuth: 30, elevation: 32, distance: 0.8, ground: false, fog: 0)
    public var size: Float = 40
    public var segments = 128
    public var relief: Float = 0.35
    public var material: MaterialKey = "ground.forest"
    /// Keep the center flat (radius, meters) so props sit cleanly.
    public var flatCenter: Float = 3
    public init() {}
    public func build(seed: UInt64) -> LODModel {
        let ns = UInt32(truncatingIfNeeded: seed)
        let s = Prim.terrain(size: V2(size, size), segments: segments, material: material) { p in
            let h = Noise.fbm(V3(p.x * 0.08, 0, p.y * 0.08), octaves: 5, seed: ns) * relief * 2
            let r = simd_length(p)
            let edge = smoothstep(size * 0.42, size * 0.5, max(abs(p.x), abs(p.y)))
            return h * smoothstep(flatCenter, flatCenter * 2.5, r) - edge * 0.05
        }
        return LODModel(Model(name: Self.id, surfaces: [s]))
    }

    /// Height at (x, z) matching the mesh (for placing instances on the ground).
    public func height(x: Float, z: Float, seed: UInt64) -> Float {
        let ns = UInt32(truncatingIfNeeded: seed)
        let p = V2(x, z)
        let h = Noise.fbm(V3(p.x * 0.08, 0, p.y * 0.08), octaves: 5, seed: ns) * relief * 2
        return h * smoothstep(flatCenter, flatCenter * 2.5, simd_length(p))
    }
}
