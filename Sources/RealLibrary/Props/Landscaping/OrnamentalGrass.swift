import simd
import Foundation

/// Fountain grass (Pennisetum alopecuroides) in late summer, 1.0 m across and 1.3 m to the plume tips:
/// a dense clump of long arching blades and 15-30 bottlebrush plumes on thin culms, nodding outward.
public struct OrnamentalGrass: RealAsset {
    public static let id = "ornamental-grass"
    public static let summary = "Fountain grass, 1.3 m: dense clump of long arching blades with 15-30 buff seed plumes."
    public static let tags = ["prop", "landscaping", "garden", "plant", "grass", "outdoor"]
    public static let budget = 12000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 30, elevation: 12)

    public var width: Float = 1.0
    public var height: Float = 1.3
    public var blades = 850
    public var plumes: ClosedRange<Int> = 15...30
    public var blade: MaterialKey = "grass.tall:3E5A22"
    public var stem: MaterialKey = "plant.stem:9A9060"
    public var plume: MaterialKey = "grass.plume"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        LODModel(levels: [model(seed: seed, detail: 1), model(seed: seed, detail: 0.4)], switchDistances: [10])
    }

    func model(seed: UInt64, detail: Float) -> Model {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let w = rng.vary(width, 0.06), h = rng.vary(height, 0.05)
        var t = PlantKit.Tuft()
        t.count = Int(Float(blades) * detail)
        t.height = h * 0.75; t.radius = 0.12
        t.heightRange = 0.55...1
        t.width = 0.008...0.012
        t.lean = 0.1...0.6; t.splay = 0.6
        t.curl = 1.1...1.9
        t.twist = 0.8
        t.segments = detail > 0.5 ? 5 : 3
        var bt = rng.fork(1)
        m.add(PlantKit.tuft(t, rng: &bt, material: blade, phase: 0.3))
        // Plumes: culm arching out, bottlebrush as three crossed cards along the last segment.
        var pr = rng.fork(2)
        var culms = Surface(material: stem), heads = Surface(material: plume)
        for i in 0..<Int(Float(pr.int(plumes)) * (detail > 0.5 ? 1 : 0.6)) {
            let rr = 0.08 * sqrt(pr.float()), a = pr.float(0...(2 * .pi))
            let base = V3(cos(a) * rr, 0, sin(a) * rr)
            let len = h * pr.float(0.85...1.0)
            let pts = PlantKit.arc(from: base, height: len, yaw: a, lean: pr.float(0.2...0.6), bend: pr.float(0.3...0.8), count: 6)
            culms.append(PlantKit.stem(pts, radius: 0.0018, tipRadius: 0.0012, sides: 3, weight: V2(0, 1), phase: Float(i) * 0.21, material: stem))
            let top = pts[pts.count - 1], ax = simd_normalize(top - pts[pts.count - 3])
            // Bottlebrush: fuzzy spike along the culm tip, fattest a third of the way up, nodding.
            let hh = pr.float(0.14...0.22)
            let rings = detail > 0.5 ? 7 : 4
            var sp: [V3] = [], rad: [Float] = []
            for k in 0...rings {
                let f = Float(k) / Float(rings)
                sp.append(top - ax * hh * (1 - f) + V3(0, -0.02 * f * f, 0))
                rad.append(0.021 * (k == rings ? 0.3 : sin(.pi * (0.15 + 0.85 * pow(f, 0.7))) * (1 - 0.3 * f) + 0.15))
            }
            heads.append(Prim.tube(sp, radii: rad, sides: detail > 0.5 ? 6 : 4, seamTile: 0.04, material: plume,
                                   weights: sp.map { _ in 1 }, phase: Float(i) * 0.21, capEnd: true))
        }
        m.add(culms); m.add(heads)
        ShrubKit.finish(&m, height: 0.25, floor: 0.4)
        PlantKit.finish(&m)
        ShrubKit.clampGround(&m)
        return ShrubKit.fit(m, size: V3(w, h, w * 0.99))
    }
}
