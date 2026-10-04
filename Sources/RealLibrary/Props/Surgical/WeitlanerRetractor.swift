import simd
import Foundation

/// Weitlaner self-retaining retractor: Satin stainless, reprocessed hospital instrument, clean.. Parts: 3-prong and 4-prong blunt rakes curving downward, straight arms, pivot screw joint, curved toothed ratchet bar on one handle, catch block with thumb release latch on the other, oval finger rings.
public struct WeitlanerRetractor: RealAsset {
    public static let id = "weitlaner-retractor"
    public static let summary = "Weitlaner self-retaining retractor, 6.5 in: 3x4 blunt rake prongs, pivot screw, curved ratchet bar with thumb release and finger rings."
    public static let tags = ["prop", "medical", "surgical", "handheld", "tool", "metal", "articulated"]
    public static let budget = 5000
    public static let author = "realityhd"

    /// Overall size in meters (x width, y height, z depth). Expose every knob a scene might tune.
    public var size = V3(0.165, 0.014, 0.06)
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        // Brief materials: metal.surgical metal.surgical-mirror. Gate: realityhd gate weitlaner-retractor. Boards: plank()/board() along +X (grain on U).
        // Turned parts: turned(). Bevel every hard edge; jitter assembled parts.
        m.add(Prim.roundedBox(size, radius: 0.01, bevelSegments: 2, material: "metal.surgical"),
              Xform(translation: V3(0, size.y / 2, 0)).jittered(&rng))
        groundAO(&m)
        return LODModel(m)
    }
}
