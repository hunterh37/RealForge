import simd
import Foundation

/// TODO: what it is, real-world dimensions, construction (parts, materials, wear).
public struct ScrubSink: RealAsset {
    public static let id = "scrub-sink"
    public static let summary = "TODO: one sentence, what it is and how it's built."
    public static let tags = ["structure", "hospital"]
    public static let budget = 20_000
    public static let author = "realityhd"

    /// Overall size in meters (x width, y height, z depth). Expose every knob a scene might tune.
    public var size = V3(2, 1.2, 0.2)
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        // Replace with the real construction. Boards: plank()/board() along +X (grain on U).
        // Turned parts: turned(). Bevel every hard edge; jitter assembled parts.
        m.add(Prim.roundedBox(size, radius: 0.01, bevelSegments: 2, material: "concrete.smooth"),
              Xform(translation: V3(0, size.y / 2, 0)).jittered(&rng))
        groundAO(&m)
        return LODModel(m)
    }
}
