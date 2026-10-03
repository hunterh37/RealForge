import simd
import Foundation

/// Knee-high meadow grass, 0.5-0.8 m: 50-70 long arching blades plus 3-6 flowering culms with loose
/// seed-head panicles (crossed cards). LOD1: three bent cards with seed stalks.
public struct TallGrass: RealAsset {
    public static let id = "tall-grass"
    public static let summary = "Knee-high meadow grass, ~0.7 m: arching geometric blades and 3-6 culms with seed-head panicles; card LOD."
    public static let tags = ["nature", "grass", "foliage"]
    public static let budget = 800
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 35, elevation: 15, distance: 1.1)

    /// Leaf blade height, meters; culms reach ~1.25x.
    public var height: Float = 0.6
    public var blades: ClosedRange<Int> = 50...70
    public var culms: ClosedRange<Int> = 3...6
    public var radius: Float = 0.06
    public var material: MaterialKey = "grass.tall"
    public var cardMaterial: MaterialKey = "grass.tall-card"
    public var seedMaterial: MaterialKey = "grass.seedhead"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        let phase = rng.float(0...6.28)
        let h = height * rng.vary(1, 0.15)
        var t = PlantKit.Tuft()
        t.count = rng.int(blades)
        t.height = h; t.radius = radius
        t.heightRange = 0.4...1
        t.width = 0.004...0.009
        t.lean = 0.05...0.25; t.splay = 0.3
        t.curl = 0.5...1.6
        t.segments = 4
        var m0 = Model(name: Self.id)
        m0.add(PlantKit.tuft(t, rng: &rng, material: material, phase: phase))
        addCulms(&m0, count: rng.int(culms), height: h, rng: &rng, phase: phase,
                 stemMaterial: "plant.stem", seedMaterial: seedMaterial)
        var m1 = Model(name: Self.id)
        m1.add(PlantKit.cardTuft(count: 3, height: h * 1.2, width: h * 0.9, segments: 2,
                                 cells: [PlantKit.cell(1, cols: 2, rows: 2), PlantKit.cell(0, cols: 2, rows: 2)],
                                 rng: &rng, material: cardMaterial, phase: phase))
        PlantKit.finish(&m0); PlantKit.finish(&m1)
        return LODModel(levels: [m0, m1], switchDistances: [10])
    }
}

/// Flowering culms: thin stems rising above the leaves, each topped by two crossed panicle cards.
func addCulms(_ m: inout Model, count: Int, height: Float, rng: inout SeededRNG, phase: Float,
              stemMaterial: MaterialKey, seedMaterial: MaterialKey, droop: ClosedRange<Float> = 0.1...0.5) {
    for _ in 0..<count {
        let r = rng.float(0...0.03), a = rng.float(0...(2 * .pi))
        let base = V3(cos(a) * r, 0, sin(a) * r)
        let ch = height * rng.float(1.05...1.35)
        let pts = PlantKit.arc(from: base, height: ch, yaw: a + rng.float(-0.5...0.5), lean: rng.float(0.03...0.18),
                               bend: rng.float(droop), count: 5)
        m.add(PlantKit.stem(pts, radius: 0.0013, tipRadius: 0.0007, weight: V2(0, 0.95), phase: phase, material: stemMaterial))
        let top = pts[pts.count - 1], axis = simd_normalize(top - pts[pts.count - 2])
        let hh = rng.float(0.1...0.17)
        m.add(PlantKit.crossedCards(at: top - axis * hh * 0.08, width: hh * 0.8, height: hh, count: 2, yaw: rng.float(0...3.14),
                                    cell: PlantKit.cell(2, cols: 2, rows: 2), weight: V2(0.95, 1.15), phase: phase,
                                    axis: axis, material: seedMaterial))
    }
}
