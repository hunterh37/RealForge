import simd
import Foundation

/// Reflex hammer: neurology pocket hammer, chrome with a black rubber disc; rubber face slightly greyed from use. Parts: knurled chrome outer handle tube, telescoping inner rod, end cap, folding head mount with hinge pin, chrome disc hub, black rubber rim ring.
public struct ReflexHammer: RealAsset {
    public static let id = "reflex-hammer"
    public static let summary = "Telescoping Babinski-style reflex hammer: chrome two-stage handle and a rubber-rimmed disc head on a folding mount."
    public static let tags = ["prop", "medical", "handheld", "articulated", "tool", "metal", "rubber"]
    public static let budget = 3500
    public static let author = "realityhd"

    /// Overall size in meters (x width, y height, z depth). Expose every knob a scene might tune.
    public var size = V3(0.19, 0.013, 0.06)
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        // Brief materials: metal.chrome metal.surgical rubber. Gate: realityhd gate reflex-hammer. Boards: plank()/board() along +X (grain on U).
        // Turned parts: turned(). Bevel every hard edge; jitter assembled parts.
        m.add(Prim.roundedBox(size, radius: 0.01, bevelSegments: 2, material: "metal.chrome"),
              Xform(translation: V3(0, size.y / 2, 0)).jittered(&rng))
        groundAO(&m)
        return LODModel(m)
    }
}
