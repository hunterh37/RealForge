import simd
import Foundation

/// English ivy ground cover, ~1 m patch: 5-8 wandering woody runners on the soil with 80-140 glossy
/// five-lobed leaves (4-9 cm) on short petioles, facing up. LOD1: flat leaves only.
public struct IvyPatch: RealAsset {
    public static let id = "ivy-patch"
    public static let summary = "English ivy ground cover, ~1 m: woody runners on the soil with 80-140 glossy five-lobed leaves; 2 LODs."
    public static let tags = ["nature", "foliage", "plant", "ground"]
    public static let budget = 1_900
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 35, elevation: 40, distance: 1.0)

    public var radius: Float = 0.5
    public var runners: ClosedRange<Int> = 5...8
    public var material: MaterialKey = "flower.meadow"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        let phase = rng.float(0...6.28)
        var m0 = Model(name: Self.id), m1 = Model(name: Self.id)
        let cell = PlantKit.cell(9, cols: 4, rows: 4)
        for _ in 0..<rng.int(runners) {
            // Runner: random walk from near the edge across the patch.
            var p = V2(rng.float(-1...1), rng.float(-1...1)) * radius * 0.5
            var heading = rng.float(0...6.28)
            var ctrl: [V3] = []
            for _ in 0..<6 {
                ctrl.append(V3(p.x, 0.008, p.y))
                heading += rng.float(-0.8...0.8)
                p += V2(cos(heading), sin(heading)) * rng.float(0.1...0.18)
                if simd_length(p) > radius * 0.9 { heading += .pi * 0.8; p *= 0.9 }
            }
            let path = catmull(ctrl, per: 4)
            var stem = PlantKit.stem(path, radius: 0.0025, tipRadius: 0.0015, weight: V2(0, 0), phase: phase, material: "plant.stem:4A3E26")
            stem.occlusion = Array(repeating: 0.6, count: stem.positions.count)
            m0.add(stem)
            // Leaves at nodes, alternating sides.
            var along: Float = 0, next: Float = 0.02, side: Float = 1
            for k in 1..<path.count {
                let seg = path[k] - path[k - 1], len = simd_length(seg)
                along += len
                while along >= next {
                    next += rng.float(0.035...0.06)
                    side = -side
                    let dir = seg / max(len, 1e-5)
                    let yaw = atan2(dir.z, dir.x) + side * rng.float(0.8...1.6)
                    var b = PlantKit.Blade()
                    b.root = path[k] + V3(0, 0.004, 0)
                    b.yaw = yaw
                    b.length = rng.float(0.05...0.09); b.width = b.length
                    b.constantWidth = true; b.tipWidth = 1
                    b.lean = rng.float(1.05...1.4); b.curl = rng.float(0...0.15); b.segments = 1
                    b.u = V2(cell.origin.x, cell.origin.x + cell.size.x); b.v = V2(cell.origin.y, cell.origin.y + cell.size.y)
                    b.weight = V2(0, rng.float(0.15...0.3)); b.phase = phase; b.ao = V2(0.55, 0.95); b.upNormal = 0.3
                    // Petiole lifts the blade 2-6 cm.
                    b.root.y += rng.float(0.01...0.05)
                    var hi = b; hi.fold = 0.08
                    m0.add(PlantKit.blade(hi, material: material))
                    m1.add(PlantKit.blade(b, material: material))
                }
            }
        }
        PlantKit.finish(&m0); PlantKit.finish(&m1)
        return LODModel(levels: [m0, m1], switchDistances: [8])
    }
}
