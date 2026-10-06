import simd
import Foundation

/// Hosta, about 0.8 m across and 0.45 m tall: a rosette of 22-32 broad heart-shaped leaves on arching
/// petioles from a central crown. Each blade is cupped, corrugated by parallel curved veins, rises
/// from the petiole and droops toward the tip; glaucous blue-green wax bloom.
public struct Hosta: RealAsset {
    public static let id = "hosta"
    public static let summary = "Hosta, 0.45 m: rosette of 22-32 broad ribbed heart-shaped leaves on arching petioles."
    public static let tags = ["prop", "landscaping", "garden", "plant", "foliage", "outdoor"]
    public static let budget = 9000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 30, elevation: 25)

    public var width: Float = 0.8
    public var height: Float = 0.45
    public var leaves: ClosedRange<Int> = 22...32
    /// Blade length range, meters (width is 60-75 percent of it).
    public var bladeLength: ClosedRange<Float> = 0.2...0.27
    public var leaf: MaterialKey = "leaf.hosta"
    public var petiole: MaterialKey = "plant.stem:7E9468"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        LODModel(levels: [model(seed: seed, detail: true), model(seed: seed, detail: false)], switchDistances: [8])
    }

    func model(seed: UInt64, detail: Bool) -> Model {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        var blades = Surface(material: leaf), stalks = Surface(material: petiole)
        let n = rng.int(leaves)
        let golden: Float = 2.39996
        for i in 0..<n {
            var r = rng.fork(i + 1)
            let inner = Float(i) / Float(n)                 // 0 outer, 1 young centre leaves
            let yaw = Float(i) * golden + r.float(-0.25...0.25)
            let dir = V3(cos(yaw), 0, sin(yaw))
            let side = V3(-dir.z, 0, dir.x)
            let reach = (0.12 - 0.08 * inner) * r.vary(1, 0.15)
            let rise = (0.07 + 0.15 * inner) * r.vary(1, 0.15)
            let root = dir * 0.015 + V3(0, 0.005, 0)
            let end = root + dir * reach + V3(0, rise, 0)
            let ctrl = root + dir * reach * 0.25 + V3(0, rise * 0.85, 0)
            let pts = catmull([root, ctrl, end], per: detail ? 3 : 2)
            stalks.append(PlantKit.stem(pts, radius: 0.0055, tipRadius: 0.004, sides: detail ? 5 : 3, weight: V2(0, 0.25), phase: Float(i) * 0.3,
                                        material: petiole))
            let L = r.float(bladeLength) * (1 - 0.25 * inner), W = L * r.float(0.78...0.9)
            let pitch0 = 0.35 + 0.55 * inner + r.float(-0.15...0.15), droop = r.float(0.8...1.3) * (1 - 0.4 * inner)
            let cup = r.float(0.08...0.16), roll = r.float(-0.15...0.15)
            let rows = detail ? 10 : 5, cols = detail ? 10 : 4
            var grid: [[UInt32]] = []
            var c = end
            var prevT = simd_normalize(dir * cos(pitch0) + V3(0, sin(pitch0), 0))
            for k in 0...rows {
                let t = Float(k) / Float(rows)
                let pitch = pitch0 - droop * t * t
                let T = simd_normalize(dir * cos(pitch) + V3(0, sin(pitch), 0))
                if k > 0 { c += (T + prevT) * 0.5 * (L / Float(rows)) }
                prevT = T
                let S = simd_quatf(angle: roll * t, axis: T).act(side)
                let N = simd_normalize(simd_cross(S, T)) * (simd_cross(S, T).y < 0 ? -1 : 1)
                let wf: Float = t < 0.32 ? 0.72 + 0.28 * sin(t / 0.32 * .pi / 2) : pow(max(0, cos((t - 0.32) / 0.68 * .pi / 2)), 0.7)
                let hw = W / 2 * wf
                var row: [UInt32] = []
                for j in 0...cols {
                    let s = Float(j) / Float(cols) * 2 - 1
                    let ripple: Float = detail ? 0.0025 * sin(abs(s) * .pi * 4) * (1 - t) : 0
                    let p = c + S * (s * hw) + N * (cup * W * s * s * wf + ripple - (k == 0 ? 0.004 : 0))
                    let v = blades.add(p, N, V2(s * hw, t * L), extra: V2(0.15 + 0.5 * t, Float(i) * 0.3))
                    blades.occlusion[Int(v)] = (0.55 + 0.45 * t) * (0.7 + 0.3 * (1 - inner))
                    row.append(v)
                }
                grid.append(row)
            }
            for k in 0..<rows { for j in 0..<cols {
                blades.quad(grid[k][j], grid[k][j + 1], grid[k + 1][j + 1], grid[k + 1][j])
            }}
        }
        blades.recomputeNormals(weldSeams: false)
        m.add(blades); m.add(stalks)
        ShrubKit.finish(&m, height: 0.15, floor: 0.5)
        PlantKit.finish(&m)
        return ShrubKit.fit(m, size: V3(width, height, width * 0.99))
    }
}
