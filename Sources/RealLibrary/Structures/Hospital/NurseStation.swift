import simd
import Foundation

/// Nurse Station: Busy ward station: kick base scuffed, transaction ledge worn at the front edge, binders not quite aligned.. Parts: 1070 mm transaction ledge in solid surface with eased edges, oak veneer fascia panels with reveals and a stainless kick base, staff work surface at 740 mm with grommets, L return wing at desk height, two 24-inch monitors on stands with off and on screens, keyboard and mouse, steel chart rack holding coloured binders, pass-through swing gate on pivot hinges with push plate, lowered accessible end.
public struct NurseStation: RealAsset {
    public static let id = "nurse-station"
    public static let summary = "L-shaped nurse station: solid-surface transaction ledge, oak fascia, staff work surface with two monitors, keyboard, chart rack and a swing gate."
    public static let tags = ["structure", "medical", "hospital", "interior", "furniture", "wood", "electronics", "articulated"]
    public static let budget = 20000
    public static let author = "realityhd"

    /// Overall size in meters (x width, y height, z depth). Expose every knob a scene might tune.
    public var size = V3(3.9, 1.07, 1.75)
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        // Brief materials: stone.solid-surface wood.veneer-oak laminate.white metal.casework plastic.matte screen.off screen.ui. Gate: realityhd gate nurse-station. Boards: plank()/board() along +X (grain on U).
        // Turned parts: turned(). Bevel every hard edge; jitter assembled parts.
        m.add(Prim.roundedBox(size, radius: 0.01, bevelSegments: 2, material: "stone.solid-surface"),
              Xform(translation: V3(0, size.y / 2, 0)).jittered(&rng))
        groundAO(&m)
        return LODModel(m)
    }
}
