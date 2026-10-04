import simd
import Foundation

/// Operating table: current electro-hydraulic general surgery table (Maquet Alphamaxx / Steris 5085 class), electropolished stainless, black pads with a scuffed kick zone on the base.. Parts: stainless base plate with rounded corners and floor locks, rectangular column shroud telescoping on a lift, four top sections: head, back, seat, legs with 80 mm black vinyl pads, radiolucent boards under the pads with stainless section frames, stainless side rails on standoffs with accessory clamps, arm board on a rail clamp, folded alongside, swings out 90 degrees, wired hand pendant hanging on the rail on a coiled cord.
public struct OperatingTable: RealAsset {
    public static let id = "operating-table"
    public static let summary = "General surgical table: stainless base and column lift, four-section radiolucent top with black pads, side rails, arm board and hand pendant."
    public static let tags = ["prop", "medical", "surgical", "articulated", "furniture", "metal", "hospital"]
    public static let budget = 15000
    public static let author = "realityhd"

    /// Overall size in meters (x width, y height, z depth). Expose every knob a scene might tune.
    public var size = V3(0.62, 0.8, 2.06)
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        // Brief materials: metal.casework metal.surgical vinyl.medical-black plastic.medical-grey plastic.medical rubber.tubing rubber. Gate: realityhd gate operating-table. Boards: plank()/board() along +X (grain on U).
        // Turned parts: turned(). Bevel every hard edge; jitter assembled parts.
        m.add(Prim.roundedBox(size, radius: 0.01, bevelSegments: 2, material: "metal.casework"),
              Xform(translation: V3(0, size.y / 2, 0)).jittered(&rng))
        groundAO(&m)
        return LODModel(m)
    }
}
