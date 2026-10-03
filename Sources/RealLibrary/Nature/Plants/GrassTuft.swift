import simd
import Foundation

/// Meadow grass tuft, ~25 cm tall from a 4 cm root disc: 30-60 geometric blades (tapered, curved,
/// twisted strips, 3-6 mm wide) with per-blade color from the `grassBlade` atlas. LOD1: three bent cards.
public struct GrassTuft: RealAsset {
    public static let id = "grass-tuft"
    public static let summary = "Meadow grass tuft, ~25 cm: 30-60 tapered, curved, twisted blade strips with per-blade color, wind weights and a card LOD."
    public static let tags = ["nature", "grass", "foliage"]
    public static let budget = 600
    public static let author = "realforge"
    public static let preview = PreviewHint(azimuth: 35, elevation: 22, distance: 1.1)

    /// Tallest blade, meters.
    public var height: Float = 0.25
    /// Blade count range; the seed picks one.
    public var blades: ClosedRange<Int> = 30...60
    /// Root disc radius, meters.
    public var radius: Float = 0.04
    public var material: MaterialKey = "grass.tall"
    public var cardMaterial: MaterialKey = "grass.tall-card"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        let phase = rng.float(0...6.28)
        var t = PlantKit.Tuft()
        t.count = rng.int(blades)
        t.height = height * rng.vary(1, 0.15)
        t.radius = radius
        t.width = 0.004...0.008
        var m0 = Model(name: Self.id)
        m0.add(PlantKit.tuft(t, rng: &rng, material: material, phase: phase))
        var m1 = Model(name: Self.id)
        m1.add(PlantKit.cardTuft(count: 3, height: t.height * 1.05, width: t.height * 1.1, segments: 2,
                                 cells: [PlantKit.cell(0, cols: 2, rows: 2)], rng: &rng, material: cardMaterial, phase: phase))
        PlantKit.finish(&m0); PlantKit.finish(&m1)
        return LODModel(levels: [m0, m1], switchDistances: [8])
    }
}
