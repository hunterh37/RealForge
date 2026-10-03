import simd
import Foundation

/// Spread of crushed gravel about 3.2 m across, 3 to 4 cm deep, with loose stones scattered past its
/// ragged edge. The bed sinks below y = 0 at the rim to blend into the ground.
public struct GravelPatch: RealAsset {
    public static let id = "gravel-patch"
    public static let summary = "Crushed-gravel spread about 3.2 m across: low mounded bed, ragged edge, loose 2 to 5 cm stones scattered past the rim."
    public static let tags = ["nature", "ground", "stone", "rock"]
    public static let budget = 11_000
    public static let preview = PreviewHint(azimuth: 30, elevation: 26, distance: 0.85)

    /// Mean radius in meters.
    public var radius: Float = 1.6
    /// Bed thickness at the center in meters.
    public var thickness: Float = 0.035
    /// Loose stones around the edge.
    public var looseStones = 28
    public var material: MaterialKey = "ground.gravel"
    public var stoneMaterial: MaterialKey = "ground.pebble-beach"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        let ns = UInt32(truncatingIfNeeded: rng.next())
        let r0 = rng.vary(radius, 0.15)
        func outline(_ a: Float) -> Float { GroundMesh.outline(a, radius: r0, wobble: 0.3, seed: ns) }
        var bed = GroundMesh.disc(material: material, rings: 24, sectors: 72, outline: outline) { p, t in
            let n = Noise.fbm(V3(p.x * 2.5, 0, p.y * 2.5), octaves: 3, seed: ns &+ 3) * 0.012
            return (thickness + n) * GroundMesh.rim(t, from: 0.55) - smoothstep(0.85, 1, t) * 0.02
        }
        bed.occlusion = bed.positions.map { 0.8 + 0.2 * smoothstep(-0.01, thickness * 0.6, $0.y) }
        var m = Model(name: Self.id, surfaces: [bed])
        // Loose stones: small displaced cube-spheres, half-sunk, mostly just outside the rim.
        var stones = Surface(material: stoneMaterial)
        for i in 0..<looseStones {
            let a = rng.float(0...(2 * .pi))
            let rr = outline(a) * (rng.chance(0.6) ? rng.float(0.85...1.3) : rng.float(0.1...0.85))
            let sz = V3(rng.float(0.02...0.05), rng.float(0.012...0.03), rng.float(0.02...0.045))
            let si = UInt32(truncatingIfNeeded: i) &+ ns
            var s = Prim.cubeSphere(subdivisions: 4, material: stoneMaterial) { d in
                d * (1 + Noise.fbm(d * 1.7, octaves: 2, seed: si) * 0.35) * sz
            }
            s.recomputeNormals()
            s.computeTangents()
            let t = rr / outline(a)
            let y = sz.y * rng.float(0.1...0.5) + thickness * GroundMesh.rim(t, from: 0.55) * 0.9
            stones.append(s, Xform(translation: V3(cos(a) * rr, y, sin(a) * rr),
                                    rotation: simd_quatf(degrees: rng.float(0...360), axis: .up)))
        }
        stones.occlusion = stones.positions.map { 0.55 + 0.45 * smoothstep(0, 0.03, $0.y) }
        m.add(stones)
        return LODModel(m)
    }
}
