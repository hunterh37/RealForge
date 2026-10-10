import simd
import Foundation

/// Cast-iron fire escape bay: a 1.6 x 0.9 m grated landing on wall brackets with a 1.05 m railing, a
/// drop-ladder hatch with counterweighted swing ladder and a stair flight descending to the left.
public struct FireEscapeLanding: RealAsset {
    public static let id = "fire-escape-landing"
    public static let summary = "Fire escape landing, 1.6 m: grated platform, rail, swing ladder, 9-tread stair flight."
    public static let tags = ["prop", "architecture", "facade", "metal", "urban"]
    public static let budget = 6_500
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 38, elevation: 16, distance: 5.4)

    public var width: Float = 1.6
    public var depth: Float = 0.9
    public var rise: Float = 2.7
    public var iron: MaterialKey = "metal.cast-iron-street"
    public var grate: MaterialKey = "metal.grate-iron"
    public var rail: MaterialKey = "metal.rust"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let W = width, D = depth, top = rise, rh: Float = 1.05
        // Platform frame and grating.
        FA.box(&m, V3(W, 0.05, 0.05), V3(0, top, D), iron, r: 0.004)
        for e: Float in [-1, 1] { FA.box(&m, V3(0.05, 0.05, D), V3(e * (W / 2 - 0.025), top, D / 2), iron, r: 0.004) }
        FA.box(&m, V3(W - 0.08, 0.012, D - 0.04), V3(0, top + 0.01, D / 2), grate, r: 0.001)
        for i in 0..<9 { FA.box(&m, V3(0.01, 0.03, D - 0.05), V3(-W / 2 + 0.1 + Float(i) * (W - 0.2) / 8, top - 0.02, D / 2), iron, r: 0.001) }
        // Diagonal wall brackets and a hanger rod.
        for e: Float in [-1, 1] {
            FA.rod(&m, V3(e * (W / 2 - 0.025), top, D), V3(e * (W / 2 - 0.025), top - 0.7, 0.0), r: 0.012, iron)
            FA.rod(&m, V3(e * (W / 2 - 0.025), top, D), V3(e * (W / 2 - 0.025), top + 0.0, 0.0), r: 0.012, iron)
            FA.box(&m, V3(0.12, 0.12, 0.012), V3(e * (W / 2 - 0.025), top - 0.7, 0.006), iron, r: 0.003)
        }
        // Railing on three sides: posts, top rail, mid rail, pickets.
        for (i, x) in [-W / 2 + 0.03, 0.0, W / 2 - 0.03].enumerated() {
            FA.rod(&m, V3(x, top, D - 0.03), V3(x, top + rh, D - 0.03), r: 0.014, rail)
            _ = i
        }
        FA.rod(&m, V3(-W / 2 + 0.03, top + rh, D - 0.03), V3(W / 2 - 0.03, top + rh, D - 0.03), r: 0.016, rail)
        FA.rod(&m, V3(-W / 2 + 0.03, top + rh * 0.5, D - 0.03), V3(W / 2 - 0.03, top + rh * 0.5, D - 0.03), r: 0.01, rail)
        for e: Float in [-1, 1] {
            FA.rod(&m, V3(e * (W / 2 - 0.03), top + rh, 0.03), V3(e * (W / 2 - 0.03), top + rh, D - 0.03), r: 0.016, rail)
            FA.rod(&m, V3(e * (W / 2 - 0.03), top, 0.03), V3(e * (W / 2 - 0.03), top + rh, 0.03), r: 0.014, rail)
        }
        for i in 0..<12 {
            let x = -W / 2 + 0.1 + Float(i) * (W - 0.2) / 11
            FA.rod(&m, V3(x, top, D - 0.03), V3(x, top + rh, D - 0.03), r: 0.006, rail, sides: 6)
        }
        // Stair flight descending to -X: stringers and ten treads.
        let sx0 = -W / 2 - 0.02, steps = 9, run: Float = 0.24, drop: Float = 0.25
        for k in 0..<steps {
            let x = sx0 - Float(k) * run - run / 2
            let y = top - Float(k + 1) * drop
            FA.box(&m, V3(run - 0.01, 0.012, 0.7), V3(x, y + 0.01, D - 0.1 + rng.float(-0.0...0.0)), grate, r: 0.001)
            FA.box(&m, V3(run, 0.03, 0.04), V3(x, y - 0.01, D - 0.1 - 0.33), iron, r: 0.002)
        }
        for z: Float in [D - 0.1 - 0.35, D - 0.1 + 0.35] {
            FA.path(&m, [V3(sx0, top, z), V3(sx0 - Float(steps) * run, top - Float(steps) * drop, z)], r: 0.018, iron, sides: 8)
            FA.path(&m, [V3(sx0, top + 0.95, z), V3(sx0 - Float(steps) * run, top - Float(steps) * drop + 0.95, z)], r: 0.014, rail, sides: 8)
        }
        // Drop-ladder hatch and swing ladder hanging from the platform front.
        FA.box(&m, V3(0.55, 0.012, 0.5), V3(0.3, top + 0.02, D / 2 - 0.08), iron, r: 0.002)
        for e: Float in [-1, 1] { FA.rod(&m, V3(0.3 + e * 0.2, top - 0.02, D - 0.2), V3(0.3 + e * 0.2, top - 1.3, D - 0.2), r: 0.012, iron) }
        for i in 0..<5 { FA.rod(&m, V3(0.1, top - 0.2 - Float(i) * 0.25, D - 0.2), V3(0.5, top - 0.2 - Float(i) * 0.25, D - 0.2), r: 0.01, iron, sides: 6) }
        groundAO(&m, height: 0.1, floor: 0.88)
        return LODModel(FC.place(m).transformed(Xform(translation: .zero)))
    }
}
