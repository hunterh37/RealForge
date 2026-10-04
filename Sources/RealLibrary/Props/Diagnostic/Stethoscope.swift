import simd
import Foundation

/// Stethoscope: current clinical stethoscope, black tube, satin stainless headset, polished chestpiece; tube slightly kinked from coat pocket storage. Parts: dual-sided stainless chestpiece: 43 mm diaphragm with silicone rim, 33 mm bell side, chestpiece stem with the tube pushed over it, single-lumen black PVC tube, 69 cm total, lying in a relaxed loop, Y junction splitting into two branches, two angled stainless eartubes, leaf tension spring between the eartubes, soft-seal grey silicone ear tips.
public struct Stethoscope: RealAsset {
    public static let id = "stethoscope"
    public static let summary = "Littmann Classic III class stethoscope lying in a loose loop: dual-head chestpiece, Y-split PVC tube, stainless headset with ear tips."
    public static let tags = ["prop", "medical", "handheld", "articulated", "tool", "metal", "rubber"]
    public static let budget = 6000
    public static let author = "realityhd"

    /// Overall size in meters (x width, y height, z depth). Expose every knob a scene might tune.
    public var size = V3(0.3, 0.03, 0.25)
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        // Brief materials: metal.surgical-mirror metal.surgical rubber.tubing rubber.silicone plastic.matte. Gate: realityhd gate stethoscope. Boards: plank()/board() along +X (grain on U).
        // Turned parts: turned(). Bevel every hard edge; jitter assembled parts.
        m.add(Prim.roundedBox(size, radius: 0.01, bevelSegments: 2, material: "metal.surgical-mirror"),
              Xform(translation: V3(0, size.y / 2, 0)).jittered(&rng))
        groundAO(&m)
        return LODModel(m)
    }
}
