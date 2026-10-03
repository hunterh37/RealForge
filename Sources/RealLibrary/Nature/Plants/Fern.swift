import simd
import Foundation

/// Lady fern (Athyrium filix-femina), fronds 0.5-0.9 m: a shuttlecock crown of 8-14 arching fronds,
/// each a ridged strip on a pinnate frond atlas. `bracken` switches to 3-6 bracken fronds held flat on
/// upright stipes. LOD1: fewer segments, no ridge.
public struct Fern: RealAsset {
    public static let id = "fern"
    public static let summary = "Lady fern, ~0.8 m fronds: crown of 8-14 arching pinnate fronds as bent, ridged strips; bracken variant; 2 LODs."
    public static let tags = ["nature", "foliage", "plant"]
    public static let budget = 700
    public static let author = "realforge"
    public static let preview = PreviewHint(azimuth: 35, elevation: 25, distance: 1.1)

    /// Longest frond, meters.
    public var length: Float = 0.8
    public var fronds: ClosedRange<Int> = 8...14
    /// Bracken (Pteridium): fewer, triangular fronds held near horizontal on 0.3-0.5 m stipes.
    public var bracken = false
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        let material: MaterialKey = bracken ? "fern.bracken" : "fern.lady"
        let phase = rng.float(0...6.28)
        let n = bracken ? rng.int(3...6) : rng.int(fronds)
        var m0 = Model(name: Self.id), m1 = Model(name: Self.id)
        let start = rng.float(0...(2 * .pi))
        for i in 0..<n {
            var b = PlantKit.Blade()
            let yaw = start + Float(i) / Float(n) * 2 * .pi + rng.float(-0.3...0.3)
            let len = length * rng.float(0.7...1.05)
            b.yaw = yaw
            b.length = len
            b.width = len * 0.5
            b.constantWidth = true; b.tipWidth = 1
            b.twist = rng.float(-0.25...0.25)
            let col = rng.int(0...3)
            let c = PlantKit.cell(col, cols: 4, rows: 1)
            b.u = V2(c.origin.x, c.origin.x + c.size.x)
            b.v = V2(0.005, 0.995)
            b.phase = phase + Float(i) * 0.3
            b.ao = V2(0.4, 1)
            b.upNormal = 0.35
            if bracken {
                let stipeH = len * rng.float(0.4...0.6)
                let r = rng.float(0.02...0.12)
                let base = V3(cos(yaw) * r, 0, sin(yaw) * r)
                let pts = PlantKit.arc(from: base, height: stipeH, yaw: yaw, lean: rng.float(0.05...0.2), bend: 0.3, count: 4)
                let stipe = PlantKit.stem(pts, radius: 0.004, tipRadius: 0.003, weight: V2(0, 0.4), phase: b.phase, material: "plant.stem:6A6A2A")
                m0.add(stipe); m1.add(stipe)
                b.root = pts[pts.count - 1]
                b.lean = rng.float(1.0...1.25); b.curl = rng.float(0.2...0.45)
                b.weight = V2(0.4, 1)
            } else {
                b.root = V3(cos(yaw), 0, sin(yaw)) * 0.025
                b.lean = rng.float(0.25...0.55); b.curl = rng.float(0.8...1.3)
            }
            var hi = b
            hi.segments = 7; hi.fold = 0.1
            m0.add(PlantKit.blade(hi, material: material))
            var lo = b
            lo.segments = 3
            m1.add(PlantKit.blade(lo, material: material))
        }
        PlantKit.finish(&m0); PlantKit.finish(&m1)
        return LODModel(levels: [m0, m1], switchDistances: [10])
    }
}
