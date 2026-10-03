import simd
import Foundation

/// Wildflower clump, 0.3-0.7 m: 7-12 stems of oxeye daisy, corn poppy, cornflower and buttercup with
/// cupped head discs, stem leaves and basal leaves from the `flowers` atlas. LOD1: lighter stems, no stem leaves.
public struct MeadowFlowers: RealAsset {
    public static let id = "meadow-flowers"
    public static let summary = "Wildflower clump, 0.3-0.7 m: daisy, poppy, cornflower and buttercup stems with cupped heads and leaves; 2 LODs."
    public static let tags = ["nature", "flower", "plant"]
    public static let budget = 800
    public static let author = "realforge"
    public static let preview = PreviewHint(azimuth: 35, elevation: 25, distance: 1.0)

    public var stems: ClosedRange<Int> = 7...12
    /// Root spread radius, meters.
    public var radius: Float = 0.1
    /// Species mix weights: daisy, poppy, cornflower, buttercup.
    public var mix: [Float] = [0.35, 0.25, 0.2, 0.2]
    public var material: MaterialKey = "flower.meadow"
    public init() {}

    /// cell, stem height, head radius, cup.
    static let species: [(cell: Int, height: ClosedRange<Float>, head: ClosedRange<Float>, cup: Float)] = [
        (0, 0.35...0.6, 0.02...0.026, -0.12),
        (1, 0.4...0.7, 0.03...0.04, 0.45),
        (2, 0.4...0.65, 0.015...0.02, 0.15),
        (3, 0.3...0.55, 0.011...0.014, 0.5),
    ]

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        let phase = rng.float(0...6.28)
        var m0 = Model(name: Self.id), m1 = Model(name: Self.id)
        let total = mix.reduce(0, +)
        for _ in 0..<rng.int(stems) {
            var pick = rng.float(0...total), si = 0
            for (k, w) in mix.enumerated() { if pick < w { si = k; break }; pick -= w; si = k }
            let sp = Self.species[si]
            let r = radius * sqrt(rng.float()), a = rng.float(0...(2 * .pi))
            let base = V3(cos(a) * r, 0, sin(a) * r)
            let h = rng.float(sp.height)
            let pts = PlantKit.arc(from: base, height: h, yaw: a + rng.float(-0.8...0.8), lean: rng.float(0.02...0.2),
                                   bend: rng.float(-0.1...0.3), count: 5)
            let sPhase = phase + rng.float(0...0.6)
            m0.add(PlantKit.stem(pts, radius: 0.0018, tipRadius: 0.0011, weight: V2(0, 1), phase: sPhase))
            m1.add(PlantKit.stem([pts[0], pts[2], pts[4]], radius: 0.0018, tipRadius: 0.0011, weight: V2(0, 1), phase: sPhase))
            let top = pts[4], axis = simd_normalize(top - pts[3])
            let face = simd_normalize(axis * 0.6 + V3(0, 0.5, 0) + V3(rng.float(-0.3...0.3), 0, rng.float(-0.3...0.3)))
            let hr = rng.float(sp.head)
            let cell = PlantKit.cell(sp.cell, cols: 4, rows: 4)
            m0.add(PlantKit.disc(center: top, normal: face, radius: hr, cup: sp.cup, rim: si == 1 ? 10 : 8, cell: cell,
                                 spin: rng.float(0...6.28), weight: 1.05, phase: sPhase, material: material))
            m1.add(PlantKit.disc(center: top, normal: face, radius: hr, cup: sp.cup, rim: 6, cell: cell,
                                 spin: rng.float(0...6.28), weight: 1.05, phase: sPhase, material: material))
            // Stem leaves.
            for k in 0..<rng.int(1...2) {
                let at = pts[1 + k]
                var b = PlantKit.Blade()
                b.root = at; b.yaw = rng.float(0...(2 * .pi))
                b.length = rng.float(0.05...0.1); b.width = b.length * 0.35
                b.constantWidth = true; b.tipWidth = 1
                b.lean = rng.float(0.6...1.0); b.curl = rng.float(0.2...0.5); b.segments = 2
                let lc = PlantKit.cell(10, cols: 4, rows: 4)
                b.u = V2(lc.origin.x, lc.origin.x + lc.size.x); b.v = V2(lc.origin.y, lc.origin.y + lc.size.y)
                let w = pow(Float(1 + k) / 4, 1.5)
                b.weight = V2(w, w + 0.15); b.phase = sPhase; b.ao = V2(0.7, 0.9)
                m0.add(PlantKit.blade(b, material: material))
            }
        }
        // Basal leaves.
        for _ in 0..<rng.int(6...10) {
            var b = PlantKit.Blade()
            let a = rng.float(0...(2 * .pi))
            b.root = V3(cos(a), 0, sin(a)) * rng.float(0...radius)
            b.yaw = a + rng.float(-0.5...0.5)
            b.length = rng.float(0.08...0.16); b.width = b.length * 0.35
            b.constantWidth = true; b.tipWidth = 1
            b.lean = rng.float(0.5...1.1); b.curl = rng.float(0.2...0.6); b.segments = 2
            let lc = PlantKit.cell(rng.chance(0.5) ? 10 : 8, cols: 4, rows: 4)
            b.u = V2(lc.origin.x, lc.origin.x + lc.size.x); b.v = V2(lc.origin.y, lc.origin.y + lc.size.y)
            b.weight = V2(0, 0.35); b.phase = phase; b.ao = V2(0.45, 0.85)
            let s = PlantKit.blade(b, material: material)
            m0.add(s); m1.add(s)
        }
        PlantKit.finish(&m0); PlantKit.finish(&m1)
        return LODModel(levels: [m0, m1], switchDistances: [9])
    }
}
