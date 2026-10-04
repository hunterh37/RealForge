import simd
import Foundation

/// IV pole with bag: Hospital ward IV stand (Pryor / Midmark class), chrome base with scuffed casters, fresh saline bag.. Parts: 5-leg cast base 63 cm across with chrome legs and hub, five 65 mm twin-wheel casters, white powder-coated outer tube 25 mm, telescoping stainless inner pole 19 mm (slide 0.9 m), twist-lock collet knob, stainless 2-hook ram's-horn top, 1 L IV bag with printed label, hanger hole, ports, drip chamber, roller clamp and line looping down.
public struct IvPole: RealAsset {
    public static let id = "iv-pole"
    public static let summary = "Telescoping IV pole: 5-leg chrome base on casters, powder-coated outer tube, twist lock, stainless 2-hook top and a 1 L IV bag with drip chamber and line."
    public static let tags = ["prop", "medical", "articulated", "hospital", "metal", "plastic"]
    public static let budget = 9000
    public static let author = "realityhd"

    /// Overall size in meters (x width, y height, z depth). Expose every knob a scene might tune.
    public var size = V3(0.63, 1.4, 0.6)
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        // Brief materials: metal.chrome metal.powder-white metal.surgical plastic.medical-grey rubber plastic.frosted label.iv fluid.saline plastic.clear. Gate: realityhd gate iv-pole. Boards: plank()/board() along +X (grain on U).
        // Turned parts: turned(). Bevel every hard edge; jitter assembled parts.
        m.add(Prim.roundedBox(size, radius: 0.01, bevelSegments: 2, material: "metal.chrome"),
              Xform(translation: V3(0, size.y / 2, 0)).jittered(&rng))
        groundAO(&m)
        return LODModel(m)
    }
}
