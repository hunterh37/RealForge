import simd
import Foundation

/// Tympanic thermometer: current home/clinic ear thermometer, gloss white, soft grey grips. Parts: curved white handle body, grey side grip insets, angled probe tip with lens, disposable probe cover, LCD window, power button, measure button, cover eject button.
public struct TympanicThermometer: RealAsset {
    public static let id = "tympanic-thermometer"
    public static let summary = "Braun ThermoScan class ear thermometer lying on its back: curved white body, probe with cover, LCD, power, measure and eject buttons."
    public static let tags = ["prop", "medical", "handheld", "articulated", "electronics", "plastic"]
    public static let budget = 5000
    public static let author = "realityhd"

    /// Overall size in meters (x width, y height, z depth). Expose every knob a scene might tune.
    public var size = V3(0.044, 0.04, 0.15)
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        // Brief materials: plastic.medical plastic.medical-grey plastic.frosted screen.off screen.lcd rubber.silicone. Gate: realityhd gate tympanic-thermometer. Boards: plank()/board() along +X (grain on U).
        // Turned parts: turned(). Bevel every hard edge; jitter assembled parts.
        m.add(Prim.roundedBox(size, radius: 0.01, bevelSegments: 2, material: "plastic.medical"),
              Xform(translation: V3(0, size.y / 2, 0)).jittered(&rng))
        groundAO(&m)
        return LODModel(m)
    }
}
