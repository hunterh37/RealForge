import simd
import Foundation

/// Stacked firewood rick, 1.2 m long, 0.9 m high, one 40 cm piece deep: split oak and birch pieces in
/// rough rows on two sleeper boards, ends ragged, top row thinning out. 2 LODs.
public struct FirewoodStack: RealAsset {
    public static let id = "firewood-stack"
    public static let summary = "Firewood rick, 1.2 x 0.9 m: split oak and birch pieces in rough rows on two sleeper boards, ragged ends."
    public static let tags = ["prop", "camp", "wood"]
    public static let budget = 10_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 28, elevation: 16, distance: 1.1)

    /// Stack length along X, meters.
    public var length: Float = 1.2
    /// Stack height, meters.
    public var height: Float = 0.9
    /// Piece length (stack depth along Z), meters.
    public var pieceLength: Float = 0.4
    /// Fraction of birch pieces (white bark).
    public var birch: Float = 0.3
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        struct Piece { var x: Float; var y: Float; var z: Float; var r: Float; var len: Float; var sweep: Float; var roll: Float; var birch: Bool; var seed: UInt64; var tilt: Float }
        var rng = SeededRNG(seed: seed)
        var pieces: [Piece] = []
        let sleeperH: Float = 0.07
        var y = sleeperH
        var row = 0
        while y < height - 0.05 {
            // Upper rows get shorter so the top reads rounded.
            let shrink = smoothstep(height * 0.65, height, y) * 0.35
            let half = length / 2 * (1 - shrink) - 0.02
            var x = -half + rng.float(0...0.04)
            var rowH: Float = 0
            while x < half {
                let sweep = rng.pick([Float.pi / 2, Float.pi / 2, 2 * Float.pi / 3, Float.pi, 2 * Float.pi])
                let r = rng.float(0.055...0.085) * (sweep > 6 ? 0.75 : 1)
                let w = sweep > 3 ? 2 * r : 2 * r * sin(min(sweep, Float.pi) / 2) * 1.1
                let h = sweep > 6 ? 2 * r : r * 1.05
                if x + w * 0.5 > half + 0.03 { break }
                pieces.append(Piece(x: x + w / 2, y: y + h / 2 + rng.float(-0.01...0.01), z: rng.float(-0.03...0.03), r: r,
                                    len: rng.vary(pieceLength, 0.08), sweep: sweep, roll: rng.float(0...(2 * .pi)),
                                    birch: rng.chance(birch), seed: rng.next(), tilt: rng.float(-3...3)))
                x += w * rng.float(0.86...0.98)
                rowH = max(rowH, h)
            }
            y += rowH * rng.float(0.8...0.9)
            row += 1
        }
        func lod(_ arc: Int) -> Model {
            var m = Model(name: Self.id)
            var rr = SeededRNG(seed: seed &+ 5)
            // Sleepers: two weathered boards along X under the pile.
            for z: Float in [-0.12, 0.12] {
                m.add(plank(length + 0.1, 0.09, sleeperH, bevel: 0.006, material: "wood.weathered"),
                      Xform(translation: V3(0, sleeperH / 2, z)).jittered(&rr, deg: 0.8))
            }
            for p in pieces {
                let w = WoodParts.splitPiece(length: p.len, radius: p.r, start: -p.sweep / 2, sweep: p.sweep,
                                             bark: p.birch ? "bark.birch" : "bark.oak-dry", split: p.birch ? "wood.pine" : "wood.oak",
                                             arcSegments: p.sweep > 6 ? arc * 2 : arc, lengthSegments: 1, seed: p.seed)
                // Piece axis X -> Z; roll about its own axis; small tilt so nothing sits CAD-flat.
                let rot = simd_quatf(degrees: p.tilt, axis: V3(1, 0, 0)) * simd_quatf(angle: .pi / 2, axis: .up) * simd_quatf(angle: p.roll, axis: V3(1, 0, 0))
                m.add(w, Xform(translation: V3(p.x, p.y, p.z), rotation: rot))
            }
            groundAO(&m, height: 0.35, floor: 0.55)
            // Pieces deep inside the pile get darker.
            for i in m.surfaces.indices {
                for v in m.surfaces[i].positions.indices {
                    let p = m.surfaces[i].positions[v]
                    let inner = 1 - smoothstep(pieceLength * 0.3, pieceLength * 0.5, abs(p.z))
                    m.surfaces[i].occlusion[v] *= 1 - inner * 0.35
                }
            }
            return m
        }
        return LODModel(levels: [lod(5), lod(3)], switchDistances: [10])
    }
}
