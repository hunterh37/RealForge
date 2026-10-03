import simd
import Foundation

/// White clover patch, ~0.4 m across and 5-10 cm high: 30-50 trefoil leaves on petioles plus 3-6
/// white flower heads (crossed cards) on stalks. LOD1: leaves and heads without petioles.
public struct CloverPatch: RealAsset {
    public static let id = "clover-patch"
    public static let summary = "White clover patch, ~0.4 m: 30-50 trefoil leaves on petioles and 3-6 white flower heads; 2 LODs."
    public static let tags = ["nature", "flower", "plant", "ground"]
    public static let budget = 800
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 35, elevation: 40, distance: 1.0)

    public var radius: Float = 0.2
    public var leaves: ClosedRange<Int> = 30...50
    public var heads: ClosedRange<Int> = 3...6
    /// Red clover heads instead of white.
    public var red = false
    public var material: MaterialKey = "flower.meadow"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        let phase = rng.float(0...6.28)
        var m0 = Model(name: Self.id), m1 = Model(name: Self.id)
        let leafCell = PlantKit.cell(7, cols: 4, rows: 4)
        for _ in 0..<rng.int(leaves) {
            let r = radius * sqrt(rng.float()), a = rng.float(0...(2 * .pi))
            let h = rng.float(0.025...0.085) * (1 - 0.4 * r / radius)
            let base = V3(cos(a) * r, 0, sin(a) * r)
            let top = base + V3(rng.float(-0.01...0.01), h, rng.float(-0.01...0.01))
            let n = simd_normalize(V3(rng.float(-0.3...0.3), 1, rng.float(-0.3...0.3)))
            let w = min(1, h / 0.08) * 0.6
            let leaf = PlantKit.disc(center: top, normal: n, radius: rng.float(0.013...0.02), cup: 0.12, rim: 6, cell: leafCell,
                                     spin: rng.float(0...6.28), weight: w, phase: phase, ao: 0.6 + 4 * h, material: material)
            m0.add(leaf); m1.add(leaf)
            m0.add(PlantKit.stem([base, top], radius: 0.0009, tipRadius: 0.0007,
                                 weight: V2(0, w), phase: phase))
        }
        let headCell = PlantKit.cell(red ? 11 : 6, cols: 4, rows: 4)
        for _ in 0..<rng.int(heads) {
            let r = radius * 0.8 * sqrt(rng.float()), a = rng.float(0...(2 * .pi))
            let base = V3(cos(a) * r, 0, sin(a) * r)
            let pts = PlantKit.arc(from: base, height: rng.float(0.08...0.14), yaw: a, lean: rng.float(0...0.2), bend: 0.2, count: 4)
            let size = rng.float(0.018...0.024)
            let stalk = PlantKit.stem(pts, radius: 0.0011, tipRadius: 0.0009, weight: V2(0, 0.8), phase: phase)
            m0.add(stalk)
            let head = PlantKit.crossedCards(at: pts[3] - V3(0, size * 0.35, 0), width: size, height: size, count: 2, yaw: rng.float(0...3),
                                             cell: headCell, weight: V2(0.8, 0.9), phase: phase, material: material)
            m0.add(head); m1.add(head)
            let cap = PlantKit.disc(center: pts[3] + V3(0, size * 0.25, 0), normal: V3(0, 1, 0), radius: size * 0.45, cup: -0.3, rim: 6,
                                    cell: headCell, spin: 0, weight: 0.9, phase: phase, material: material)
            m0.add(cap); m1.add(cap)
        }
        PlantKit.finish(&m0); PlantKit.finish(&m1)
        return LODModel(levels: [m0, m1], switchDistances: [7])
    }
}
