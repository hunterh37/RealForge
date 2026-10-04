import simd
import Foundation

/// Disposable safety scalpel: Single-use sterile scalpel, new, clean molded plastic.. Parts: molded white handle with scale-pattern grip ribs, #10 carbon-steel blade with curved belly, translucent blue sliding shield with thumb tab, blade guard detent and lock notch, blade size mark.
public struct Scalpel: RealAsset {
    public static let id = "scalpel"
    public static let summary = "Disposable safety scalpel with a #10 blade: ribbed molded handle and a translucent blue shield that slides over the blade."
    public static let tags = ["prop", "medical", "surgical", "handheld", "tool", "plastic", "metal", "articulated"]
    public static let budget = 3500
    public static let author = "realityhd"

    /// Overall size in meters (x width, y height, z depth). Expose every knob a scene might tune.
    public var size = V3(0.156, 0.011, 0.017)
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        // Brief materials: plastic.medical metal.surgical-mirror plastic.scalpel-shield. Gate: realityhd gate scalpel. Boards: plank()/board() along +X (grain on U).
        // Turned parts: turned(). Bevel every hard edge; jitter assembled parts.
        m.add(Prim.roundedBox(size, radius: 0.01, bevelSegments: 2, material: "plastic.medical"),
              Xform(translation: V3(0, size.y / 2, 0)).jittered(&rng))
        groundAO(&m)
        return LODModel(m)
    }
}
