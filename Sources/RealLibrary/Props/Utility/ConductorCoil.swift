import simd
import Foundation

/// Coil of 1/0 ACSR (Raven, 6/1) bare conductor, about 30 m, lying flat as a lineman keeps a splice
/// remnant on the truck: loose bundled turns of 10.1 mm stranded aluminum over a galvanized steel core,
/// held by three twists of tie wire, both cut ends sticking out with the outer strands splayed.
public struct ConductorCoil: RealAsset {
    public static let id = "conductor-coil"
    public static let summary = "Coil of 1/0 ACSR bare conductor, about 30 m: stranded aluminum over a steel core, tied with three wraps of tie wire, cut ends showing strands."
    public static let tags = ["prop", "utility", "electrical", "metal"]
    public static let budget = 14000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 20, elevation: 35, distance: 1.0, studio: true)

    /// Mean coil radius (m).
    public var radius: Float = 0.27
    /// Number of turns.
    public var turns = 17
    /// Conductor diameter (m). 1/0 ACSR: 10.1 mm.
    public var diameter: Float = 0.0101
    public var strand: MaterialKey = "metal.acsr-strand"
    public var tie: MaterialKey = "metal.galvanized"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let r = diameter / 2
        let per = 44
        // Bundle cross-section: each turn sits at its own (radial, height) slot with a slow wander.
        var path: [V3] = []
        let cols = 5
        for t in 0..<turns {
            let slot = V2(Float(t % cols) - Float(cols - 1) / 2, Float(t / cols))
            let ph = rng.float(0...6.28), amp = rng.float(0.003...0.009)
            for i in 0..<per {
                let u = (Float(t) + Float(i) / Float(per))
                let a = u * 2 * .pi
                let rr = radius + slot.x * diameter * 1.05 + amp * sin(a * 3 + ph)
                let y = r + slot.y * diameter * 0.95 + 0.002 * max(0, sin(a * 2 + ph))
                path.append(V3(cos(a) * rr, y, sin(a) * rr))
            }
        }
        // Cut ends leave the bundle tangentially.
        let first = path[0], last = path[path.count - 1]
        let t0 = simd_normalize(path[0] - path[1]), t1 = simd_normalize(last - path[path.count - 2])
        path.insert(first + t0 * 0.08 + V3(0, 0.004, 0), at: 0)
        path.append(last + t1 * 0.11 + V3(0, 0.006, 0))
        m.add(Prim.tube(path, radii: path.map { _ in r }, sides: 7, seamTile: 0.03, material: strand))
        // Cut ends: steel core poking out, outer strands flared.
        for (p, d) in [(path[0], t0), (path[path.count - 1], t1)] {
            m.add(Prim.tube([p, p + d * 0.012], radii: [r * 0.33, r * 0.33], sides: 6, seamTile: 0.02, material: "metal.galvanized-aged"))
            let a = simd_normalize(simd_cross(d, .up)), b = simd_cross(a, d)
            for k in 0..<6 {
                let ang = Float(k) / 6 * 2 * .pi
                let o = (a * cos(ang) + b * sin(ang))
                m.add(Prim.tube([p + o * r * 0.66, p + o * r * 1.2 + d * 0.01], radii: [r * 0.33, r * 0.3], sides: 5, seamTile: 0.02, material: strand))
            }
        }
        // Three tie-wire wraps around the bundle.
        let bundleH = Float((turns - 1) / cols + 1) * diameter, bundleW = Float(cols) * diameter * 1.05
        for k in 0..<3 {
            let a = Float(k) / 3 * 2 * .pi + 0.4
            let c = V3(cos(a) * radius, bundleH / 2, sin(a) * radius)
            let radial = V3(cos(a), 0, sin(a)), tang = V3(-sin(a), 0, cos(a))
            for w in 0..<2 {
                var loop: [V3] = []
                for i in 0...20 {
                    let q = Float(i) / 20 * 2 * .pi
                    loop.append(c + radial * cos(q) * (bundleW / 2 + 0.002) + V3(0, sin(q) * (bundleH / 2 + 0.002), 0) + tang * (Float(w) * 0.004 - 0.002))
                }
                m.add(Prim.tube(loop, radii: loop.map { _ in 0.0012 }, sides: 4, seamTile: 0.02, material: tie))
            }
            // Twisted pigtail.
            let tp = c + radial * (bundleW / 2 + 0.002)
            m.add(Prim.tube(catmull([tp, tp + radial * 0.012 + V3(0, 0.003, 0), tp + radial * 0.022 + tang * 0.004], per: 3), radii: Array(repeating: 0.0014, count: 7), sides: 4, seamTile: 0.02, material: tie))
        }
        groundAO(&m, height: 0.04, floor: 0.55)
        return LODModel(m)
    }
}
