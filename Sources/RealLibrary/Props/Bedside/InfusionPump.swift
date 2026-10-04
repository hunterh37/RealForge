import simd
import Foundation

/// Infusion pump: Current volumetric pump (Alaris GP / B. Braun class), used: scuffed door edge, asset tag label.. Parts: two-tone molded housing with carry handle, color LCD in a bezel (off/on), membrane keypad with start/stop and arrow keys, status LEDs, hinged door over the pumping segment with latch lever, IV tubing set passing through the door channel, rear pole clamp with T-handle clamp screw, rubber feet and side vents, rating label.
public struct InfusionPump: RealAsset {
    public static let id = "infusion-pump"
    public static let summary = "Large-volume infusion pump channel: grey housing, LCD with keypad, hinged door over the pumping segment, tubing set, rear pole clamp with screw."
    public static let tags = ["prop", "medical", "articulated", "electronics", "hospital", "plastic"]
    public static let budget = 8000
    public static let author = "realityhd"

    /// Overall size in meters (x width, y height, z depth). Expose every knob a scene might tune.
    public var size = V3(0.145, 0.25, 0.21)
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        // Brief materials: plastic.medical plastic.medical-grey screen.off metal.chrome rubber plastic.clear label.rx emissive.led-green. Gate: realityhd gate infusion-pump. Boards: plank()/board() along +X (grain on U).
        // Turned parts: turned(). Bevel every hard edge; jitter assembled parts.
        m.add(Prim.roundedBox(size, radius: 0.01, bevelSegments: 2, material: "plastic.medical"),
              Xform(translation: V3(0, size.y / 2, 0)).jittered(&rng))
        groundAO(&m)
        return LODModel(m)
    }
}
