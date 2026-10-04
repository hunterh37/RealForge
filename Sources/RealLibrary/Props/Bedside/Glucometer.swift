import simd
import Foundation

/// Blood glucose meter: Current home meter (OneTouch Verio Flex / Accu-Chek Guide class), used: smudged screen.. Parts: rounded meter body 88 x 47 x 12 mm, soft-touch sides, segment LCD (off/on/reading 104 mg/dL), three buttons, strip port with test strip that slides in, blood drop on the strip (reading), pen lancing device with slide-off cap and release button.
public struct Glucometer: RealAsset {
    public static let id = "glucometer"
    public static let summary = "Blood glucose meter with sliding test strip, segment LCD showing a reading, three buttons, and a pen lancing device with a removable cap."
    public static let tags = ["prop", "medical", "articulated", "handheld", "electronics", "plastic"]
    public static let budget = 4000
    public static let author = "realityhd"

    /// Overall size in meters (x width, y height, z depth). Expose every knob a scene might tune.
    public var size = V3(0.115, 0.018, 0.085)
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        // Brief materials: plastic.medical plastic.medical-grey plastic.black screen.off screen.lcd rubber. Gate: realityhd gate glucometer. Boards: plank()/board() along +X (grain on U).
        // Turned parts: turned(). Bevel every hard edge; jitter assembled parts.
        m.add(Prim.roundedBox(size, radius: 0.01, bevelSegments: 2, material: "plastic.medical"),
              Xform(translation: V3(0, size.y / 2, 0)).jittered(&rng))
        groundAO(&m)
        return LODModel(m)
    }
}
