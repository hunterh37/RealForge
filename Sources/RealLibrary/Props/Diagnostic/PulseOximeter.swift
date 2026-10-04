import simd
import Foundation

/// Pulse oximeter: consumer/clinic fingertip oximeter, blue gloss top over grey base. Parts: top shell with OLED window, bottom shell, rear spring hinge, silicone finger pads, power button, lanyard loop, label on the underside.
public struct PulseOximeter: RealAsset {
    public static let id = "pulse-oximeter"
    public static let summary = "Fingertip pulse oximeter, 58 x 32 x 34 mm: spring clamshell with silicone finger pads, OLED SpO2 display, power button and lanyard."
    public static let tags = ["prop", "medical", "handheld", "articulated", "electronics", "plastic", "rubber"]
    public static let budget = 5000
    public static let author = "realityhd"

    /// Overall size in meters (x width, y height, z depth). Expose every knob a scene might tune.
    public var size = V3(0.07, 0.034, 0.032)
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        // Brief materials: plastic.gloss plastic.matte rubber.silicone screen.off screen.oximeter fabric.nylon. Gate: realityhd gate pulse-oximeter. Boards: plank()/board() along +X (grain on U).
        // Turned parts: turned(). Bevel every hard edge; jitter assembled parts.
        m.add(Prim.roundedBox(size, radius: 0.01, bevelSegments: 2, material: "plastic.gloss"),
              Xform(translation: V3(0, size.y / 2, 0)).jittered(&rng))
        groundAO(&m)
        return LODModel(m)
    }
}
