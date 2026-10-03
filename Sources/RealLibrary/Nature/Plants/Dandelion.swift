import simd
import Foundation

/// Dandelion (Taraxacum), rosette ~0.4 m across: 6-10 toothed leaves as cupped strips lying low, and
/// 1-3 hollow scapes 12-30 cm tall carrying a yellow flower head or a white seed clock. LOD1: flat leaves.
public struct Dandelion: RealAsset {
    public static let id = "dandelion"
    public static let summary = "Dandelion: rosette of 6-10 toothed leaves and 1-3 hollow stalks with a yellow head or white seed clock; 2 LODs."
    public static let tags = ["nature", "flower", "plant"]
    public static let budget = 450
    public static let author = "realforge"
    public static let preview = PreviewHint(azimuth: 35, elevation: 35, distance: 1.0)

    /// Chance that a scape carries a seed clock instead of a flower.
    public var clockChance: Float = 0.35
    public var material: MaterialKey = "flower.meadow"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        let phase = rng.float(0...6.28)
        var m0 = Model(name: Self.id), m1 = Model(name: Self.id)
        let leafCell = PlantKit.cell(8, cols: 4, rows: 4)
        let n = rng.int(6...10)
        let start = rng.float(0...6.28)
        for i in 0..<n {
            var b = PlantKit.Blade()
            b.yaw = start + Float(i) / Float(n) * 2 * .pi + rng.float(-0.25...0.25)
            b.root = V3(cos(b.yaw), 0.004, sin(b.yaw)) * 0.01
            b.length = rng.float(0.12...0.22); b.width = b.length * 0.5
            b.constantWidth = true; b.tipWidth = 1
            b.lean = rng.float(0.95...1.3); b.curl = rng.float(0.1...0.35)
            b.u = V2(leafCell.origin.x, leafCell.origin.x + leafCell.size.x); b.v = V2(leafCell.origin.y, leafCell.origin.y + leafCell.size.y)
            b.weight = V2(0, 0.3); b.phase = phase; b.ao = V2(0.45, 0.95); b.upNormal = 0.3
            var hi = b; hi.segments = 3; hi.fold = -0.1
            var lo = b; lo.segments = 2
            m0.add(PlantKit.blade(hi, material: material)); m1.add(PlantKit.blade(lo, material: material))
        }
        for _ in 0..<rng.int(1...3) {
            let a = rng.float(0...6.28)
            let clock = rng.chance(clockChance)
            let h = clock ? rng.float(0.2...0.32) : rng.float(0.12...0.25)
            let pts = PlantKit.arc(from: V3(cos(a), 0, sin(a)) * 0.012, height: h, yaw: a, lean: rng.float(0.05...0.3), bend: rng.float(-0.2...0.2), count: 5)
            let sPhase = phase + rng.float(0...0.5)
            m0.add(PlantKit.stem(pts, radius: 0.0022, tipRadius: 0.0018, weight: V2(0, 1), phase: sPhase, material: "plant.stem:6E8A3A"))
            m1.add(PlantKit.stem([pts[0], pts[2], pts[4]], radius: 0.0022, tipRadius: 0.0018, weight: V2(0, 1), phase: sPhase, material: "plant.stem:6E8A3A"))
            let top = pts[4]
            if clock {
                let r: Float = rng.float(0.018...0.022)
                let cards = PlantKit.crossedCards(at: top - V3(0, r, 0), width: 2 * r, height: 2 * r, count: 3, yaw: rng.float(0...3),
                                                  cell: PlantKit.cell(5, cols: 4, rows: 4), weight: V2(1, 1.05), phase: sPhase, material: material)
                m0.add(cards); m1.add(cards)
            } else {
                let axis = simd_normalize(simd_normalize(top - pts[3]) + V3(0, 0.6, 0))
                let head = PlantKit.disc(center: top, normal: axis, radius: rng.float(0.017...0.022), cup: -0.15, rim: 10,
                                         cell: PlantKit.cell(4, cols: 4, rows: 4), spin: rng.float(0...6), weight: 1.05, phase: sPhase, material: material)
                m0.add(head); m1.add(head)
            }
        }
        PlantKit.finish(&m0); PlantKit.finish(&m1)
        return LODModel(levels: [m0, m1], switchDistances: [7])
    }
}
