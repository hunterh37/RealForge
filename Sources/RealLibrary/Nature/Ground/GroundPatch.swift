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
    /// Worn footpath width in meters (0 = none). The path meanders through the center along `pathHeading`
    /// and is painted into the splat channel, so `wornMaterial` must carry a splat layer.
    public var pathWidth: Float = 0
    /// Path direction in degrees around +Y (0 = along X).
    public var pathHeading: Float = 0
    /// Material used when `pathWidth > 0` (`ground.forest-worn`, `ground.meadow-worn`).
    public var wornMaterial: MaterialKey = "ground.forest-worn"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var s = Prim.terrain(size: V2(size, size), segments: segments, material: pathWidth > 0 ? wornMaterial : material) { p in
            height(x: p.x, z: p.y, seed: seed) - edgeDrop(p)
        }
        if hollowShade > 0 { GroundMesh.shadeHollows(&s, gridSide: segments + 1, radius: max(2, segments / 24), relief: relief, strength: hollowShade) }
        if pathWidth > 0 {
            let ns = UInt32(truncatingIfNeeded: seed) &+ 31
            // Trodden center sinks 2 cm; the worn edge is ragged.
            for i in s.positions.indices { s.positions[i].y -= 0.02 * pathWear(s.positions[i], ns) }
            s.recomputeNormals(weldSeams: false); s.computeTangents()
            s.paintSplat { pathWear($0, ns) }
        }
        return LODModel(Model(name: Self.id, surfaces: [s]))
    }

    /// Path wear 0...1 at a point: 1 on the trodden line, ragged falloff over about half the width.
    public func pathWear(x: Float, z: Float, seed: UInt64) -> Float {
        pathWidth > 0 ? pathWear(V3(x, 0, z), UInt32(truncatingIfNeeded: seed) &+ 31) : 0
    }

    func pathWear(_ p: V3, _ ns: UInt32) -> Float {
        let a = pathHeading * .pi / 180
        let u = p.x * cos(a) - p.z * sin(a), v = p.x * sin(a) + p.z * cos(a)
        let center = 1.4 * sin(u * 0.13 + Float(ns % 7)) + 0.5 * sin(u * 0.37 + 1)
        let d = abs(v - center) + Noise.fbm(V3(p.x * 2.2, 1, p.z * 2.2), octaves: 3, seed: ns) * 0.3
        return 1 - smoothstep(pathWidth * 0.3, pathWidth * 0.75, d)
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
