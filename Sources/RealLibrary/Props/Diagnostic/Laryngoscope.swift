import simd
import Foundation

/// Laryngoscope: reusable stainless anaesthesia set, autoclave-dulled blade. Parts: knurled chrome handle, end cap, hinge block with the hook-on bar, Macintosh curved blade with flange and tongue, fiber-optic light guide and tip, blade heel with the spring detent.
public struct Laryngoscope: RealAsset {
    public static let id = "laryngoscope"
    public static let summary = "Macintosh #3 fiber-optic laryngoscope standing on a knurled chrome C-cell handle, blade folded on the hinge bar or locked open and lit."
    public static let tags = ["prop", "medical", "handheld", "articulated", "surgical", "tool", "metal", "light"]
    public static let budget = 5000
    public static let author = "realityhd"

    /// Overall size in meters (x width, y height, z depth). Expose every knob a scene might tune.
    public var size = V3(0.032, 0.16, 0.06)
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        // Brief materials: metal.chrome metal.surgical metal.surgical-mirror emissive.surgical glass.clear. Gate: realityhd gate laryngoscope. Boards: plank()/board() along +X (grain on U).
        // Turned parts: turned(). Bevel every hard edge; jitter assembled parts.
        m.add(Prim.roundedBox(size, radius: 0.01, bevelSegments: 2, material: "metal.chrome"),
              Xform(translation: V3(0, size.y / 2, 0)).jittered(&rng))
        groundAO(&m)
        return LODModel(m)
    }
}
