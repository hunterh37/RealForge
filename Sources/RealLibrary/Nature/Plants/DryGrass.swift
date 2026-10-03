import simd
import Foundation

/// Late-summer dry grass, ~45 cm: straw-colored, partly flopped blades (some broken short), a few green
/// blades left, and 2-5 bleached seed heads. LOD1: three bent cards.
public struct DryGrass: RealAsset {
    public static let id = "dry-grass"
    public static let summary = "Straw-colored summer grass, ~45 cm: flopped and broken geometric blades with pale seed heads; card LOD."
    public static let tags = ["nature", "grass", "foliage"]
    public static let budget = 700
    public static let author = "realforge"
    public static let preview = PreviewHint(azimuth: 35, elevation: 18, distance: 1.1)

    public var height: Float = 0.45
    public var blades: ClosedRange<Int> = 40...58
    public var culms: ClosedRange<Int> = 2...5
    public var radius: Float = 0.05
    public var material: MaterialKey = "grass.dry"
    public var cardMaterial: MaterialKey = "grass.dry-card"
    public var seedMaterial: MaterialKey = "grass.seedhead"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        let phase = rng.float(0...6.28)
        let h = height * rng.vary(1, 0.15)
        var t = PlantKit.Tuft()
        t.count = rng.int(blades)
        t.height = h; t.radius = radius
        t.heightRange = 0.35...1
        t.width = 0.003...0.007
        t.lean = 0.1...0.45; t.splay = 0.5
        t.curl = 0.6...2.0
        t.twist = 1.2
        t.segments = 4
        var m0 = Model(name: Self.id)
        m0.add(PlantKit.tuft(t, rng: &rng, material: material, phase: phase))
        // Broken stubs: short blunt blades.
        var stubs = t
        stubs.count = max(3, t.count / 6); stubs.height = h * 0.35; stubs.heightRange = 0.4...1
        stubs.curl = 0...0.3; stubs.segments = 2; stubs.mown = true
        m0.add(PlantKit.tuft(stubs, rng: &rng, material: material, phase: phase))
        addCulms(&m0, count: rng.int(culms), height: h, rng: &rng, phase: phase,
                 stemMaterial: "plant.stem:B8A672", seedMaterial: seedMaterial, droop: 0.2...0.8)
        var m1 = Model(name: Self.id)
        m1.add(PlantKit.cardTuft(count: 3, height: h * 1.1, width: h * 1.0, segments: 2,
                                 cells: [PlantKit.cell(0, cols: 2, rows: 2), PlantKit.cell(1, cols: 2, rows: 2)],
                                 rng: &rng, material: cardMaterial, phase: phase, lean: 0.25))
        PlantKit.finish(&m0); PlantKit.finish(&m1)
        return LODModel(levels: [m0, m1], switchDistances: [8])
    }
}
