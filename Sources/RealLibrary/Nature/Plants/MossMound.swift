import simd
import Foundation

/// Cushion moss, 0.25-0.6 m across and 3-9 cm high: 1-3 merged, lumpy domes (displaced cube-spheres
/// with flat bases) covered in the tiling `moss` program. LOD1: coarser domes.
public struct MossMound: RealAsset {
    public static let id = "moss-mound"
    public static let summary = "Cushion moss mound, 0.25-0.6 m across: 1-3 merged lumpy domes with a dense moss-shoot material; 2 LODs."
    public static let tags = ["nature", "plant", "ground"]
    public static let budget = 1_600
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 35, elevation: 30, distance: 1.0)

    /// Main dome radius and height, meters.
    public var radius: Float = 0.2
    public var height: Float = 0.06
    public var material: MaterialKey = "moss.cushion"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m0 = Model(name: Self.id), m1 = Model(name: Self.id)
        let n = rng.int(1...3)
        for i in 0..<n {
            let s: Float = i == 0 ? 1 : rng.float(0.45...0.7)
            let rx = radius * s * rng.vary(1, 0.15), rz = radius * s * rng.vary(1, 0.15), ry = height * s * rng.vary(1, 0.2)
            let off = i == 0 ? V2.zero : V2(cos(Float(i) * 2.3), sin(Float(i) * 2.3)) * radius * rng.float(0.6...0.9)
            let ns = UInt32(truncatingIfNeeded: seed &+ UInt64(i) * 7)
            func shape(_ d: V3) -> V3 {
                let bump = 1 + 0.1 * Noise.fbm(d * 2.2, octaves: 3, seed: ns) + 0.035 * Noise.fbm(d * 9, octaves: 2, seed: ns + 3)
                let y = d.y > 0 ? pow(d.y, 0.8) * ry * bump : d.y * 0.015
                // Flatten the sides near the ground so the cushion meets the soil.
                let spread = d.y > 0 ? 1 : 1 + d.y * 0.1
                return V3(d.x * rx * bump * spread, y, d.z * rz * bump * spread)
            }
            for (lod, sub) in [(0, 6), (1, 3)] {
                var dome = Prim.cubeSphere(subdivisions: sub, material: material, radius: shape)
                dome.occlusion = dome.positions.map { 0.55 + 0.45 * saturate($0.y / max(ry, 0.01) * 1.6) }
                let x = Xform(translation: V3(off.x, -0.008, off.y), rotation: simd_quatf(angle: rng.float(0...6.28), axis: .up))
                if lod == 0 { m0.add(dome, x) } else { m1.add(dome, x) }
            }
        }
        return LODModel(levels: [m0, m1], switchDistances: [8])
    }
}
