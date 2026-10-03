import simd
import Foundation

/// Round bale, 1.5 m diameter x 1.2 m wide (5 x 4 ft), lying on its side: rolled straw with spiral layers on
/// the ends, net wrap over the curved face, flattened where it rests on the ground.
public struct RoundHayBale: RealAsset {
    public static let id = "round-hay-bale"
    public static let summary = "Round hay bale, 1.5 m x 1.2 m: rolled straw, spiral layers on the ends, net wrap, flattened base."
    public static let tags = ["prop", "farm"]
    public static let budget = 6_000
    public static let author = "hunter"
    public static let preview = PreviewHint(azimuth: 40, elevation: 14)

    public var diameter: Float = 1.5
    public var width: Float = 1.2
    public var side: MaterialKey = "straw.hay-net"
    public var ends: MaterialKey = "straw.hay"
    public var lodDistances: [Float] = [20, 50]
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        let R = rng.vary(diameter / 2, 0.04), W = rng.vary(width, 0.03)
        let ns = UInt32(truncatingIfNeeded: seed)
        let sag = rng.float(0.05...0.09)
        func level(_ seg: Int, _ endRings: Int) -> Model {
            var m = Model(name: Self.id)
            // Curved face with rounded shoulders; y here is the bale axis.
            var sideProf: [V2] = []
            for k in 0...8 { let t = Float(k) / 8; let y = lerp(-W / 2 + 0.06, W / 2 - 0.06, t); sideProf.append(V2(R + 0.012 * sin(.pi * t), y)) }
            sideProf.insert(V2(R - 0.035, -W / 2 + 0.005), at: 0); sideProf.append(V2(R - 0.035, W / 2 - 0.005))
            m.add(Prim.lathe(sideProf, segments: seg, seamTile: 0.6, material: side))
            // Ends: concentric layers rippling in and out, slightly domed.
            for sy: Float in [-1, 1] {
                var prof: [V2] = []
                for k in 0...endRings {
                    let t = Float(k) / Float(endRings), r = (R - 0.035) * (1 - t)
                    let y = sy * (W / 2 - 0.005 + 0.02 * t + 0.006 * sin(r * 55))
                    prof.append(V2(r, y))
                }
                if sy < 0 { prof.reverse() }
                m.add(Prim.lathe(prof, segments: seg, seamTile: 0.45, material: ends))
            }
            // Lay it on its side, add lumps, flatten the contact patch.
            for i in m.surfaces.indices {
                var s = m.surfaces[i]
                s.positions = s.positions.map { p0 in
                    var p = V3(p0.y, -p0.x, p0.z)     // rotate the axis onto X
                    let d = simd_normalize(V3(0, p.y, p.z) + V3(0.0001, 0, 0))
                    p += d * Noise.fbm(p * 2.2, octaves: 3, seed: ns) * 0.03
                    p.y += R
                    let floorY = R * sag
                    p.y = p.y < floorY ? max(p.y, 0) / floorY * 0.01 : p.y - floorY + 0.01
                    return p
                }
                let minY = s.positions.map(\.y).min() ?? 0
                s.positions = s.positions.map { V3($0.x, $0.y - minY, $0.z) }
                s.recomputeNormals()
                s.computeTangents()
                s.occlusion = s.positions.map { 0.45 + 0.55 * smoothstep(0, R * 0.6, $0.y) }
                m.surfaces[i] = s
            }
            return m
        }
        return LODModel(levels: [level(56, 14), level(28, 7), level(14, 3)], switchDistances: lodDistances)
    }
}
