import simd
import Foundation

/// River-rock bed, 1.4 x 0.7 m by default: an oval swale of 5-15 cm rounded river stones packed over
/// a thin pea-gravel base, larger stones near the center, a few half-buried at the margin. Stones are
/// displaced, flattened cube-spheres in mixed river-rock tones; some read wet from a recent rain.
public struct RiverRockBed: RealAsset {
    public static let id = "river-rock-bed"
    public static let summary = "River-rock bed, 1.4 x 0.7 m: oval swale of packed 5-15 cm rounded river stones over pea gravel, larger stones at the center."
    public static let tags = ["prop", "garden", "outdoor", "landscaping", "stone", "rock", "ground"]
    public static let budget = 14_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 22, elevation: 36, distance: 1.0, studio: true)

    /// Bed length along X (m).
    public var length: Float = 1.4
    /// Bed width along Z (m).
    public var width: Float = 0.7
    /// Number of stones.
    public var stones: Int = 170
    /// Stone size range (longest axis, m).
    public var stoneSize: ClosedRange<Float> = 0.05...0.15
    /// Stone materials, picked per stone.
    public var stoneKeys: [MaterialKey] = ["rock.river", "rock.river:8A8278", "rock.river:6E6A64", "rock.river-wet"]
    /// Gravel base material.
    public var gravel: MaterialKey = "ground.gravel"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id), lite = Model(name: Self.id + "-lite")
        let hx = length / 2, hz = width / 2
        // Gravel base: shallow oval mound, feathered at the rim.
        let sd = UInt32(truncatingIfNeeded: rng.int(0...100_000))
        var base = Surface(material: gravel)
        let rings = 12, segs = 64
        for j in 0...rings { for i in 0...segs {
            let t = Float(j) / Float(rings), a = Float(i) / Float(segs) * 2 * .pi
            let wob = 1 + 0.05 * Noise.fbm(V3(cos(a) * 2, sin(a) * 2, 0), octaves: 2, seed: sd + 3)
            let p = V2(cos(a) * hx * 1.06, sin(a) * hz * 1.08) * t * wob
            let y = j == rings ? 0.0005 : 0.022 * pow(1 - t, 0.5) + 0.004 * Noise.fbm(V3(p.x * 9, 0, p.y * 9), seed: sd)
            base.add(V3(p.x, max(0.0005, y), p.y), .up, V2(p.x, -p.y))
        }}
        let row = UInt32(segs + 1)
        for j in 0..<UInt32(rings) { for i in 0..<UInt32(segs) { let q = j * row + i; base.quad(q, q + 1, q + row + 1, q + row) } }
        base.recomputeNormals(weldSeams: true); base.computeTangents()
        m.add(base); lite.add(base)
        // Stones: Poisson-ish placement by rejection in the oval, biggest first near the center.
        var placed: [(V2, Float)] = []
        var tries = 0
        while placed.count < stones && tries < stones * 60 {
            tries += 1
            let p = V2(rng.float(-hx...hx), rng.float(-hz...hz))
            let e = sqrt(pow(p.x / hx, 2) + pow(p.y / hz, 2))
            guard e < 1.0 else { continue }
            let big = 1 - e * 0.6
            let size = stoneSize.lowerBound + (stoneSize.upperBound - stoneSize.lowerBound) * pow(rng.float(), 1.6) * big
            let rad = size * 0.42
            if placed.contains(where: { simd_distance($0.0, p) < ($0.1 + rad) * 0.78 }) { continue }
            placed.append((p, rad))
        }
        for (k, (p, rad)) in placed.enumerated() {
            var r = rng.fork(k)
            let len = rad / 0.42
            let size = V3(len, len * r.float(0.35...0.55), len * r.float(0.6...0.85))
            let ss = UInt32(truncatingIfNeeded: r.int(0...100_000))
            let key = stoneKeys[r.int(0...(stoneKeys.count - 1))]
            var s = Prim.superellipsoid(size, exponent: 2.4, subdivisions: len > 0.09 ? 3 : 2, material: key) { d in
                1 + 0.06 * Noise.fbm(d * 1.6, octaves: 3, seed: ss)
            }
            s.recomputeNormals(weldSeams: true)
            let e = sqrt(pow(p.x / hx, 2) + pow(p.y / hz, 2))
            let baseY = 0.025 * pow(max(0, 1 - e), 0.5)
            let sink = size.y * (e > 0.8 ? 0.45 : 0.25)
            let xf = Xform(translation: V3(p.x, baseY + size.y / 2 - sink, p.y),
                           rotation: simd_quatf(degrees: r.float(0...360), axis: .up) * simd_quatf(degrees: r.float(-12...12), axis: V3(1, 0, 0)))
            m.add(s, xf)
            if rad > 0.03 { lite.add(Prim.superellipsoid(size, exponent: 2.4, subdivisions: 2, material: key), xf) }
        }
        // Silt left in the low spots after the last rain, and a few dry oak leaves caught between stones.
        for k in 0..<10 {
            var r = rng.fork(700 + k)
            let p = V2(r.float(-hx...hx) * 0.8, r.float(-hz...hz) * 0.7)
            m.add(Prim.superellipsoid(V3(r.float(0.08...0.18), 0.012, r.float(0.05...0.12)), exponent: 2.2, subdivisions: 3, material: "ground.mud"),
                  Xform(translation: V3(p.x, 0.018, p.y), rotation: simd_quatf(degrees: r.float(0...180), axis: .up)))
        }
        for k in 0..<7 {
            var r = rng.fork(800 + k)
            let p = V2(r.float(-hx...hx) * 0.85, r.float(-hz...hz) * 0.8)
            let len = r.float(0.06...0.1)
            let leaf = Prim.superellipsoid(V3(len, 0.003, len * 0.5), exponent: 2.2, subdivisions: 2, material: "bark.oak-dry:6E5032") { d in 1 + 0.4 * d.x * d.x }
            m.add(leaf, Xform(translation: V3(p.x, 0.06, p.y), rotation: simd_quatf(degrees: r.float(0...360), axis: .up) * simd_quatf(degrees: r.float(-25...25), axis: V3(1, 0, 0))))
        }
        groundAO(&m, height: 0.08, floor: 0.55); groundAO(&lite, height: 0.08, floor: 0.55)
        return LODModel(levels: [m, lite], switchDistances: [10])
    }
}
