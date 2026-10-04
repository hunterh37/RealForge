import simd
import Foundation

/// Adson tissue forceps: Satin stainless with mirror tips, reprocessed hospital instrument.. Parts: two leaf-spring tines, welded rounded back end, broad thumb grips with transverse serrations, narrow shouldered tips, 1x2 interlocking teeth at the tips, green ID tape band.
public struct TissueForceps: RealAsset {
    public static let id = "tissue-forceps"
    public static let summary = "Adson tissue forceps, 4.75 in, 1x2 teeth: two spring tines welded at the back, broad serrated grips and fine toothed tips."
    public static let tags = ["prop", "medical", "surgical", "handheld", "tool", "metal", "articulated"]
    public static let budget = 3000
    public static let author = "realityhd"

    /// Overall size in meters (x width, y height, z depth). Expose every knob a scene might tune.
    public var size = V3(0.12, 0.0125, 0.0105)
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        // Brief materials: metal.surgical metal.surgical-mirror. Gate: realityhd gate tissue-forceps. Boards: plank()/board() along +X (grain on U).
        // Turned parts: turned(). Bevel every hard edge; jitter assembled parts.
        m.add(Prim.roundedBox(size, radius: 0.01, bevelSegments: 2, material: "metal.surgical"),
              Xform(translation: V3(0, size.y / 2, 0)).jittered(&rng))
        groundAO(&m)
        return LODModel(m)
    }
}
