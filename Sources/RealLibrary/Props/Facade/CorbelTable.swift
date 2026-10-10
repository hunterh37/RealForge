import simd
import Foundation

/// Brick corbel table: a frieze of stepped arched corbels under a projecting drip course, 2.0 m long,
/// 0.36 m tall. Each corbel steps out in three brick courses; small round arches span the gaps.
public struct CorbelTable: RealAsset {
    public static let id = "corbel-table"
    public static let summary = "Brick corbel table, 2.0 m: stepped corbels, small arches between, projecting drip course."
    public static let tags = ["prop", "architecture", "facade", "trim", "brick"]
    public static let budget = 12_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 30, elevation: 15, distance: 3.2)

    public var length: Float = 2.0
    public var pitch: Float = 0.25
    public var brick: MaterialKey = "brick.red"
    public var cap: MaterialKey = "stone.cast-stone"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let L = length, n = Int(L / pitch)
        // Wall backing course and the drip cap.
        FA.box(&m, V3(L, 0.36, 0.1), V3(0, 0.18, 0.05), brick, r: 0.002)
        FA.box(&m, V3(L + 0.04, 0.05, 0.2), V3(0, 0.385, 0.1), cap, r: 0.004)
        for i in 0..<n {
            let x = -Float(n - 1) * pitch / 2 + Float(i) * pitch
            // Three-step corbel: 0.065 m courses, each stepping out 0.03 m.
            for s in 0..<3 {
                let w = 0.14 - Float(s) * 0.025
                let y = 0.3 - Float(s) * 0.07
                let jitter = rng.float(-0.002...0.002)
                FA.box(&m, V3(w, 0.066, 0.1 + Float(2 - s) * 0.03), V3(x + jitter, y, (0.1 + Float(2 - s) * 0.03) / 2), brick, r: 0.003)
            }
            // Little arch between this corbel and the next.
            if i < n - 1 {
                let c = V3(x + pitch / 2, 0.22, 0.09)
                m.add(Prim.torus(major: 0.045, minor: 0.016, segments: 14, sides: 5, material: brick), Xform(translation: c, rotation: FA.q(90, FA.X)))
            }
        }
        groundAO(&m, height: 0.1, floor: 0.85)
        return LODModel(FA.centerZ(m))
    }
}
