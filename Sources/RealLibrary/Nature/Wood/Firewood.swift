import simd
import Foundation

/// One split firewood piece, 40 cm long from a 15 cm round: a quarter, third or half wedge (or an unsplit
/// round) with bark on the outer arc, rough split faces and sawn end grain. Lies along X on its flat side.
public struct Firewood: RealAsset {
    public static let id = "firewood"
    public static let summary = "Split firewood piece, 40 cm from a 15 cm round: bark arc, rough split faces, sawn end-grain caps."
    public static let tags = ["nature", "wood", "camp"]
    public static let budget = 1_000
    public static let author = "realforge"
    public static let preview = PreviewHint(azimuth: 62, elevation: 24, distance: 1.2)

    /// Piece length in meters (stove and fire-pit wood is cut to 30 to 45 cm).
    public var length: Float = 0.4
    /// Diameter of the round it was split from, meters.
    public var diameter: Float = 0.15
    /// Bark material on the outer arc.
    public var bark: MaterialKey = "bark.oak-dry"
    /// Split face material (grain along the piece).
    public var split: MaterialKey = "wood.oak"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        let sweep = rng.pick([Float.pi / 2, Float.pi / 2, 2 * Float.pi / 3, Float.pi, 2 * Float.pi])
        let L = rng.vary(length, 0.1), R = rng.vary(diameter / 2, 0.15)
        func lod(_ arc: Int, _ segs: Int) -> Model {
            let p = WoodParts.splitPiece(length: L, radius: R, start: -sweep / 2, sweep: sweep, bark: bark, split: split,
                                         arcSegments: arc, lengthSegments: segs, seed: seed)
            // The wedge bisector points up (+Y); roll it onto one split face, then ground it.
            let rot = simd_quatf(angle: sweep > 6 ? 0 : .pi / 2 - sweep / 2, axis: V3(1, 0, 0))
            var m = p.transformed(Xform(rotation: rot))
            let b = m.bounds
            m = m.transformed(Xform(translation: V3(0, -b.min.y, -(b.min.z + b.max.z) / 2)))
            groundAO(&m, height: 0.08, floor: 0.6)
            return m
        }
        let arc = sweep > 3.5 ? 14 : sweep > 2 ? 10 : 6
        return LODModel(levels: [lod(arc, 2), lod(max(3, arc / 2), 1)], switchDistances: [8])
    }
}
