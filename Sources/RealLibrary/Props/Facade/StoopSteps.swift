import simd
import Foundation

/// Brownstone stoop: six solid stone steps 1.4 m wide climbing 1.1 m to a top landing, side cheek
/// walls, and two wrought-iron railings with newel posts, scroll infill and brass-capped finials.
public struct StoopSteps: RealAsset {
    public static let id = "stoop-steps"
    public static let summary = "Brownstone stoop, 1.4 m wide: six steps, cheek walls, iron railings with newels."
    public static let tags = ["prop", "architecture", "facade", "stone", "metal", "urban"]
    public static let budget = 8_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 40, elevation: 16, distance: 5.4)

    public var width: Float = 1.4
    public var steps: Int = 6
    public var riser: Float = 0.18
    public var tread: Float = 0.3
    public var stone: MaterialKey = "stone.brownstone"
    public var worn: MaterialKey = "stone.limestone-sooted"
    public var iron: MaterialKey = "metal.wrought-iron"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let W = width, n = steps, R = riser, T = tread, landing: Float = 1.0
        let totalRun = Float(n) * T + landing
        // Steps (solid blocks from the ground up, so each is a full volume).
        for i in 0..<n {
            let h = Float(i + 1) * R
            let z = totalRun - Float(i) * T - T / 2 - landing
            FA.box(&m, V3(W, h, T), V3(0, h / 2, z + landing), stone, r: 0.006)
            FA.box(&m, V3(W + 0.04, 0.035, T + 0.03), V3(0, h - 0.017, z + landing + 0.015), worn, r: 0.008)
        }
        let top = Float(n) * R
        FA.box(&m, V3(W + 0.06, top, landing), V3(0, top / 2, landing / 2), stone, r: 0.006)
        FA.box(&m, V3(W + 0.1, 0.05, landing + 0.04), V3(0, top - 0.025, landing / 2), worn, r: 0.008)
        // Cheek walls with a sloped cap.
        for e: Float in [-1, 1] {
            let x = e * (W / 2 + 0.1)
            let prof = [V2(0, 0), V2(totalRun, 0), V2(totalRun, R * 1.3), V2(landing, top + 0.1), V2(0, top + 0.1)]
            m.add(Prim.extrude(prof.map { V2($0.x, $0.y) }, depth: 0.16, bevel: 0.006, bevelSegments: 1, material: stone),
                  Xform(translation: V3(x, 0, 0), rotation: FA.q(-90, FA.Y)))
            // Railing on the cheek.
            let z0 = landing, z1 = totalRun
            let hr: Float = 0.9
            let p0 = V3(x, top + 0.1, z0), p1 = V3(x, 1.3 * R, z1)
            for t in 0...8 {
                let f = Float(t) / 8
                let p = p0 + (p1 - p0) * f
                FA.rod(&m, p, p + V3(0, hr, 0), r: 0.008, iron, sides: 6)
            }
            FA.rod(&m, p0 + V3(0, hr, 0), p1 + V3(0, hr, 0), r: 0.016, iron)
            FA.rod(&m, p0 + V3(0, hr * 0.15, 0), p1 + V3(0, hr * 0.15, 0), r: 0.01, iron)
            for p in [p0, p1] {
                FA.rod(&m, p, p + V3(0, hr + 0.12, 0), r: 0.022, iron)
                FA.ball(&m, r: 0.035, at: p + V3(0, hr + 0.15, 0), "metal.brass-aged")
            }
            let mid = (p0 + p1) / 2 + V3(0, hr * 0.5, 0)
            m.add(Prim.torus(major: 0.12, minor: 0.008, segments: 22, sides: 6, material: iron), Xform(translation: mid + V3(0, 0, 0), rotation: FA.q(90, FA.Z)))
        }
        groundAO(&m, height: 0.12, floor: 0.7)
        return LODModel(FC.place(m))
    }
}
