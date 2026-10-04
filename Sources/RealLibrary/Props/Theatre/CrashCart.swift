import simd
import Foundation

/// Crash cart: Harloff class emergency cart, red powder coat with scuffs on the bumper and drawer edges, a daily check log clipped to the side.. Parts: red steel cabinet on 125 mm casters with a bumper, five drawers with full-width aluminium pulls, breakaway lock with a numbered plastic seal, top with a raised rim, defibrillator shelf on a post, O2 cylinder holder with a green cylinder on the side, CPR board on the back, push handle.
public struct CrashCart: RealAsset {
    public static let id = "crash-cart"
    public static let summary = "Emergency crash cart: red powder-coated cabinet with five drawers, breakaway seal, rimmed top, O2 tank holder, CPR board and defib shelf."
    public static let tags = ["prop", "medical", "hospital", "articulated", "furniture", "container", "metal"]
    public static let budget = 14000
    public static let author = "realityhd"

    /// Overall size in meters (x width, y height, z depth). Expose every knob a scene might tune.
    public var size = V3(0.98, 1.3, 0.66)
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        // Brief materials: metal.powdercoat:B3201C metal.aluminum-brushed plastic.matte plastic.medical-grey rubber metal.powdercoat:2E7D4F. Gate: realityhd gate crash-cart. Boards: plank()/board() along +X (grain on U).
        // Turned parts: turned(). Bevel every hard edge; jitter assembled parts.
        m.add(Prim.roundedBox(size, radius: 0.01, bevelSegments: 2, material: "metal.powdercoat:B3201C"),
              Xform(translation: V3(0, size.y / 2, 0)).jittered(&rng))
        groundAO(&m)
        return LODModel(m)
    }
}
