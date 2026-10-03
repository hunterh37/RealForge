import simd
import Foundation

/// Broadleaf cattail (Typha latifolia) clump, ~1.8 m: 30-45 flat sword leaves 1-2 cm wide arching at
/// the top, and 2-4 flower spikes with a brown velvet head (15-20 cm, 2.6 cm thick) under a thin
/// tan spike. LOD1: fewer leaf segments, 5-sided heads.
public struct ReedClump: RealAsset {
    public static let id = "reed-clump"
    public static let summary = "Cattail clump, ~1.8 m: flat sword leaves arching at the top and 2-4 stems with brown velvet seed heads; 2 LODs."
    public static let tags = ["nature", "grass", "plant", "water"]
    public static let budget = 1_100
    public static let author = "realforge"
    public static let preview = PreviewHint(azimuth: 35, elevation: 12, distance: 1.1)

    public var height: Float = 1.8
    public var leaves: ClosedRange<Int> = 30...45
    public var spikes: ClosedRange<Int> = 2...4
    public var radius: Float = 0.12
    public var material: MaterialKey = "grass.reed"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        let phase = rng.float(0...6.28)
        var t = PlantKit.Tuft()
        t.count = rng.int(leaves)
        t.height = height * rng.vary(1, 0.1)
        t.heightRange = 0.55...1
        t.radius = radius
        t.width = 0.011...0.02
        t.lean = 0.0...0.1; t.splay = 0.12
        t.curl = 0.15...0.9; t.twist = 0.6
        var m0 = Model(name: Self.id), m1 = Model(name: Self.id)
        var r0 = rng.fork(1), r1 = rng.fork(1)
        t.segments = 5; m0.add(PlantKit.tuft(t, rng: &r0, material: material, phase: phase))
        t.segments = 3; m1.add(PlantKit.tuft(t, rng: &r1, material: material, phase: phase))
        for _ in 0..<rng.int(spikes) {
            let a = rng.float(0...6.28), r = rng.float(0...radius * 0.7)
            let h = height * rng.float(0.8...1.05)
            let pts = PlantKit.arc(from: V3(cos(a) * r, 0, sin(a) * r), height: h, yaw: a, lean: rng.float(0...0.06), bend: rng.float(0...0.08), count: 5)
            let sPhase = phase + rng.float(0...0.4)
            let stem = PlantKit.stem(pts, radius: 0.0045, tipRadius: 0.003, weight: V2(0, 0.8), phase: sPhase, material: "plant.stem:5E7A3A")
            m0.add(stem); m1.add(stem)
            let top = pts[4], axis = simd_normalize(top - pts[3])
            let headLen = rng.float(0.15...0.2), headR = rng.float(0.012...0.015)
            let hb = top - axis * (headLen + 0.12)
            let hp = (0...5).map { hb + axis * headLen * Float($0) / 5 }
            let hr: [Float] = [0.0035, headR * 0.9, headR, headR, headR * 0.92, 0.003]
            let hw: [Float] = [0.72, 0.74, 0.76, 0.78, 0.8, 0.8]
            for (sides, m) in [(8, 0), (5, 1)] {
                var head = Prim.tube(hp, radii: hr, sides: sides, seamTile: 0.05, material: "plant.cattail", weights: hw, phase: sPhase, capEnd: true)
                head.occlusion = Array(repeating: 0.9, count: head.positions.count)
                if m == 0 { m0.add(head) } else { m1.add(head) }
            }
            let spike = PlantKit.stem([hp[5], hp[5] + axis * 0.06, top + axis * 0.02], radius: 0.0018, tipRadius: 0.0008,
                                      weight: V2(0.8, 0.85), phase: sPhase, material: "plant.stem:9A8660")
            m0.add(spike)
        }
        PlantKit.finish(&m0); PlantKit.finish(&m1)
        return LODModel(levels: [m0, m1], switchDistances: [14])
    }
}
