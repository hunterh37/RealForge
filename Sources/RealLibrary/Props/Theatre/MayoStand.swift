import simd
import Foundation

/// Mayo instrument stand: hospital stainless Mayo stand (Pedigo / Blickman class), polished tubes, drape crease lines, a towel clip on the drape edge.. Parts: stainless tube U-base with four 50 mm casters, outer column tube with a black lock knob, inner telescoping column, cantilever arm and tray frame, removable stainless tray with rolled rim, blue drape over the tray, instruments on the drape: scissors, hemostats, forceps, scalpel.
public struct MayoStand: RealAsset {
    public static let id = "mayo-stand"
    public static let summary = "Mayo instrument stand: stainless U-base on casters, telescoping column with a lock knob, draped stainless tray with instruments."
    public static let tags = ["prop", "medical", "surgical", "articulated", "metal", "furniture"]
    public static let budget = 8000
    public static let author = "realityhd"

    /// Overall size in meters (x width, y height, z depth). Expose every knob a scene might tune.
    public var size = V3(0.48, 0.96, 0.62)
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        // Brief materials: metal.casework metal.surgical metal.surgical-mirror drape.surgical plastic.black rubber. Gate: realityhd gate mayo-stand. Boards: plank()/board() along +X (grain on U).
        // Turned parts: turned(). Bevel every hard edge; jitter assembled parts.
        m.add(Prim.roundedBox(size, radius: 0.01, bevelSegments: 2, material: "metal.casework"),
              Xform(translation: V3(0, size.y / 2, 0)).jittered(&rng))
        groundAO(&m)
        return LODModel(m)
    }
}
