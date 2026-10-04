import simd
import Foundation

/// Patient monitor: Current ICU monitor (Philips IntelliVue MX500 class), clean, light wear on the handle.. Parts: 15 in display with vitals screen (off/on/alarm), molded two-tone housing with rear vents and carry handle, alarm light bar across the top (off/red), hard keys and power LED under the screen, tilt head with friction knobs, short arm and wall channel plate with screws, measurement cable entries on the side.
public struct PatientMonitor: RealAsset {
    public static let id = "patient-monitor"
    public static let summary = "15 in bedside patient monitor on a tilting wall-channel mount: grey bezel, vitals display, alarm light bar, rear handle and tilt bracket."
    public static let tags = ["prop", "medical", "articulated", "electronics", "hospital", "plastic", "metal"]
    public static let budget = 9000
    public static let author = "realityhd"

    /// Overall size in meters (x width, y height, z depth). Expose every knob a scene might tune.
    public var size = V3(0.37, 0.36, 0.25)
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        // Brief materials: plastic.medical plastic.medical-grey screen.off screen.vitals screen.vitals-alarm emissive.led-red metal.powder-white metal.chrome. Gate: realityhd gate patient-monitor. Boards: plank()/board() along +X (grain on U).
        // Turned parts: turned(). Bevel every hard edge; jitter assembled parts.
        m.add(Prim.roundedBox(size, radius: 0.01, bevelSegments: 2, material: "plastic.medical"),
              Xform(translation: V3(0, size.y / 2, 0)).jittered(&rng))
        groundAO(&m)
        return LODModel(m)
    }
}
