import simd
import Foundation

/// Privacy Curtain: Contemporary ward fit-out; curtain slightly creased along the fold lines, hem a touch darker where hands pull it, one carrier skipped.. Parts: surface-mounted aluminium C-channel track with end stops and ceiling clips, nylon roller carriers with chrome S-hooks every 150 mm, 500 mm open-weave mesh top band with nickel grommets, pleated flame-retardant curtain body hanging to 300 mm above the floor, double-folded weighted hem, leading-edge pull tab panel that slides with the lead carrier, gathered stack at the wall end when open.
public struct PrivacyCurtain: RealAsset {
    public static let id = "privacy-curtain"
    public static let summary = "Hospital cubicle curtain: 3 m ceiling track with nylon carriers, white mesh top band and pleated teal curtain that draws open, half or closed."
    public static let tags = ["structure", "medical", "hospital", "interior", "fabric", "metal", "articulated"]
    public static let budget = 16000
    public static let author = "realityhd"

    /// Overall size in meters (x width, y height, z depth). Expose every knob a scene might tune.
    public var size = V3(3.04, 2.43, 0.12)
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        // Brief materials: metal.aluminum-brushed fabric.curtain fabric.curtain-mesh plastic.white metal.chrome. Gate: realityhd gate privacy-curtain. Boards: plank()/board() along +X (grain on U).
        // Turned parts: turned(). Bevel every hard edge; jitter assembled parts.
        m.add(Prim.roundedBox(size, radius: 0.01, bevelSegments: 2, material: "metal.aluminum-brushed"),
              Xform(translation: V3(0, size.y / 2, 0)).jittered(&rng))
        groundAO(&m)
        return LODModel(m)
    }
}
