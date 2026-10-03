import simd
import Foundation

/// Grass clump for dense fields, ~0.42 m: four crossed alpha cards, each bent in two segments, with
/// root-to-tip wind weights. LOD1: three flat cards. Instance by the thousand; `grass-tuft` is the
/// close-range geometric version.
public struct GrassClump: RealAsset {
    public static let id = "grass-clump"
    public static let summary = "Grass clump, ~0.42 m: four bent, crossed alpha cards with seed stalks and wind weights; flat 3-card LOD."
    public static let tags = ["nature", "grass", "foliage"]
    public static let budget = 64
    public var height: Float = 0.42
    public var width: Float = 0.5
    public var material: MaterialKey = "grass.tall-card"
    public init() {}
    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        let phase = rng.float(0...6.28)
        let cells = [PlantKit.cell(0, cols: 2, rows: 2), PlantKit.cell(1, cols: 2, rows: 2)]
        var m0 = Model(name: Self.id), m1 = Model(name: Self.id)
        m0.add(PlantKit.cardTuft(count: 4, height: height, width: width, segments: 2, cells: cells, rng: &rng,
                                 material: material, phase: phase, lean: 0.18))
        m1.add(PlantKit.cardTuft(count: 3, height: height, width: width, segments: 1, cells: cells, rng: &rng,
                                 material: material, phase: phase, lean: 0.1))
        PlantKit.finish(&m0); PlantKit.finish(&m1)
        return LODModel(levels: [m0, m1], switchDistances: [15])
    }
}
