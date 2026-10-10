import simd
import Foundation

/// Loose slab of oak bark, 40 cm long, curled to the trunk it fell from: ridged grey-brown bark on
/// the outside, pale fibrous inner face, ragged torn ends and edges, 1.5 cm thick.
public struct BarkSlab: RealAsset {
    public static let id = "bark-slab"
    public static let summary = "Loose oak bark slab, 40 cm: curled ridged bark, pale fibrous inner face, ragged torn edges; handheld, liftable."
    public static let tags = ["prop", "wood", "outdoor", "handheld"]
    public static let budget = 6_000
    public static let preview = PreviewHint(azimuth: 35, elevation: 30, distance: 1.0)

    public var length: Float = 0.40
    /// Radius of the trunk it came from and the arc it spans (radians).
    public var trunkRadius: Float = 0.13
    public var arc: Float = 1.35
    public var thickness: Float = 0.015
    public var bark: MaterialKey = "bark.oak"
    public var inner: MaterialKey = "wood.deadwood"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        LODModel(levels: [model(seed: seed, nu: 22, nv: 36), model(seed: seed, nu: 10, nv: 14)], switchDistances: [5])
    }

    func model(seed: UInt64, nu: Int, nv: Int) -> Model {
        var rng = SeededRNG(seed: seed)
        let sd = rng.float(0...40)
        // Ragged outline: arc half-width and end offsets vary along the slab.
        func halfArc(_ v: Float) -> Float { arc * 0.5 * (0.85 + 0.15 * Noise.fbm(V3(v * 4, sd, 0), octaves: 3)) * (0.75 + 0.25 * sqrt(sin(max(0.02, v) * .pi))) }
        func endZ(_ u: Float, _ front: Bool) -> Float {
            (front ? 1 : -1) * length * 0.5 * (1 - 0.06 * abs(Noise.fbm(V3(u * 6, front ? sd : sd + 9, 3), octaves: 2)) - 0.03 * u * u)
        }
        func point(_ u: Float, _ v: Float, _ r: Float) -> V3 {
            let a = (u * 2 - 1) * halfArc(v)
            let z = endZ(u, false) + (endZ(u, true) - endZ(u, false)) * v
            let ridge = r > trunkRadius ? 0.004 * abs(sin(a * 28 + Noise.fbm(V3(a, z * 8, sd), octaves: 2) * 3)) : 0
            return V3(sin(a) * (r + ridge), cos(a) * (r + ridge) - trunkRadius * cos(arc * 0.5) - thickness * 0.3, z)
        }
        func sheet(_ r: Float, _ mat: MaterialKey, _ flip: Bool) -> Surface {
            var s = Surface(material: mat)
            for j in 0...nv { for i in 0...nu {
                let u = Float(i) / Float(nu), v = Float(j) / Float(nv)
                let p = point(u, v, r)
                _ = s.add(p, .up, V2(atan2(p.x, p.y) * r, p.z))
            }}
            let row = UInt32(nu + 1)
            for j in 0..<UInt32(nv) { for i in 0..<UInt32(nu) {
                let a = j * row + i
                if flip { s.quad(a, a + 1, a + row + 1, a + row) } else { s.quad(a, a + row, a + row + 1, a + 1) }
            }}
            s.recomputeNormals(weldSeams: false); s.computeTangents()
            return s
        }
        let ro = trunkRadius + thickness, ri = trunkRadius
        var m = Model(name: Self.id)
        m.add(sheet(ro, bark, false))
        m.add(sheet(ri, inner, true))
        // Torn rim: strip joining outer and inner along the four edges.
        var rim = Surface(material: "wood.endgrain-weathered")
        var loop: [(Float, Float)] = []
        for i in 0...nu { loop.append((Float(i) / Float(nu), 0)) }
        for j in 1...nv { loop.append((1, Float(j) / Float(nv))) }
        for i in stride(from: nu - 1, through: 0, by: -1) { loop.append((Float(i) / Float(nu), 1)) }
        for j in stride(from: nv - 1, through: 1, by: -1) { loop.append((0, Float(j) / Float(nv))) }
        var acc: Float = 0
        for (k, (u, v)) in loop.enumerated() {
            let o = point(u, v, ro), i = point(u, v, ri)
            if k > 0 { let (pu, pv) = loop[k - 1]; acc += simd_distance(point(pu, pv, ro), o) }
            _ = rim.add(o, .up, V2(acc, 0)); _ = rim.add(i, .up, V2(acc, thickness))
        }
        let n = UInt32(loop.count)
        for k in 0..<n { let a = k * 2, b = ((k + 1) % n) * 2; rim.quad(a, b, b + 1, a + 1) }
        rim.recomputeNormals(weldSeams: false); rim.computeTangents()
        m.add(rim)
        let b = m.bounds
        m = m.transformed(Xform(translation: V3(-(b.min.x + b.max.x) / 2, -b.min.y, -(b.min.z + b.max.z) / 2)))
        groundAO(&m, height: 0.06, floor: 0.55)
        return m
    }
}
