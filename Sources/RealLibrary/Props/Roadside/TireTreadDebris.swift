import simd
import Foundation

/// Blown truck-tire tread strip ("road gator"): curled black rubber with tread blocks and exposed steel belt wire.
public struct TireTreadDebris: RealAsset {
    public static let id = "tire-tread-debris"
    public static let summary = "Strip of shredded truck tire tread, 1.1 m long, 12 cm wide with curled ends, tread blocks and exposed steel belt wires."
    public static let tags = ["prop", "road", "vehicle", "rubber", "outdoor"]
    public static let budget = 10000
    public static let author = "realityhd"

    /// Strip length along X in meters.
    public var length: Float = 1.1
    /// Strip width in meters.
    public var width: Float = 0.12
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let n = 24, th: Float = 0.016
        // Centreline: gentle S in plan, ends curl up. Local frame per station for width direction.
        func centre(_ t: Float) -> V3 {
            let x = (t - 0.5) * length
            let curl = max(0, abs(t - 0.5) * 2 - 0.62) / 0.38
            let y = 0.004 + curl * curl * 0.07
            return V3(x, y, sin(t * 5.2) * 0.07)
        }
        var stations: [(V3, V3)] = []   // position, across-direction
        for k in 0...n {
            let t = Float(k) / Float(n)
            let c = centre(t), c2 = centre(min(1, t + 0.01)), c1 = centre(max(0, t - 0.01))
            let tangent = simd_normalize(c2 - c1)
            var across = simd_normalize(simd_cross(V3(0, 1, 0), tangent))
            // Strip twists as it curls up at the ends.
            let curl = max(0, abs(t - 0.5) * 2 - 0.62) / 0.38
            let up = V3(0, 1, 0)
            across = simd_normalize(across * cos(curl * 0.9 * (t < 0.5 ? -1 : 1)) + simd_cross(tangent, across) * sin(curl * 0.9 * (t < 0.5 ? -1 : 1)))
            _ = up
            stations.append((c, across))
        }
        // Skin: a loft of rounded-rect cross-sections (outer tread face on top).
        let sec: [V2] = Shape2D.roundedRect(width, th, radius: 0.005, segments: 2)
        var rings: [[V3]] = []
        for (c, a) in stations {
            let up = simd_normalize(simd_cross(a, simd_normalize(V3(1, 0, 0) - a * a.x)))
            let upv = up.y < 0 ? -up : up
            rings.append(sec.map { c + a * $0.x + upv * $0.y })
        }
        m.add(Prim.loft(rings, capStart: true, capEnd: true, material: "rubber.truck-tire"))
        // Tread blocks across the outer face.
        for k in 1..<n {
            let t = Float(k) / Float(n)
            let (c, a) = stations[min(n, Int(t * Float(n)))]
            let up = simd_normalize(simd_cross(a, V3(1, 0, 0)))
            let upv = up.y < 0 ? -up : up
            for s in -1...1 {
                let off = Float(s) * 0.036
                let basis = simd_float3x3(columns: (simd_normalize(simd_cross(upv, a)), upv, a))
                m.add(Prim.roundedBox(V3(0.02, 0.01, 0.028), radius: 0.002, bevelSegments: 1, material: "rubber.truck-tire"),
                      Xform(translation: c + a * off + upv * (th / 2 + 0.004), rotation: simd_quatf(basis)))
            }
        }
        // Exposed steel belt wires at the ragged ends and torn edge.
        for end: Float in [0, 1] {
            for _ in 0..<7 {
                let (c, a) = stations[end == 0 ? 0 : n]
                let dir: Float = end == 0 ? -1 : 1
                let p0 = c + a * rng.float(-0.05...0.05)
                let p1 = p0 + V3(dir * rng.float(0.03...0.09), rng.float(0.01...0.045), rng.float(-0.03...0.03))
                let p2 = p1 + V3(dir * rng.float(0.02...0.06), rng.float(-0.02...0.02), rng.float(-0.04...0.04))
                m.add(Prim.tube([p0, p1, p2], radii: [0.0018, 0.0018, 0.0012], sides: 5, seamTile: 0.05, material: "metal.steel", capEnd: true))
            }
        }
        // Flat white road dust scuffs on the face.
        for _ in 0..<4 {
            let t = rng.float(0.15...0.85)
            let c = centre(t)
            m.add(Prim.superellipsoid(V3(rng.float(0.05...0.12), 0.0016, rng.float(0.02...0.04)), exponent: 3, subdivisions: 4, material: "plastic.white"),
                  Xform(translation: V3(c.x, c.y + th / 2 + 0.0011, c.z + rng.float(-0.03...0.03))))
        }
        // Shift to the ground and centre.
        let b = m.bounds
        m = m.transformed(Xform(translation: V3(-(b.min.x + b.max.x) / 2, -b.min.y, -(b.min.z + b.max.z) / 2)))
        groundAO(&m, height: 0.04, floor: 0.5)
        return LODModel(m)
    }
}
