import simd
import Foundation

/// Beam Seating: Clinic waiting room, a few years in service: seat fronts slightly worn, arm pads scuffed.. Parts: 80 x 40 mm powder-coated steel beam, two T-legs with foot bars and floor glides, four upholstered vinyl seat pads on molded shells, four upholstered backs on shells with steel spines, three fixed armrests between seats with polyurethane pads, two hinged end arms that swing up, fold-down laminate tablet arm on the right end.
public struct BeamSeating: RealAsset {
    public static let id = "beam-seating"
    public static let summary = "Four-seat waiting-room beam seating: steel beam on T-legs, teal vinyl seats and backs on black shells, lift-up end arms and a fold-down tablet."
    public static let tags = ["prop", "medical", "hospital", "interior", "furniture", "metal", "plastic", "articulated"]
    public static let budget = 15000
    public static let author = "realityhd"

    /// Overall size in meters (x width, y height, z depth). Expose every knob a scene might tune.
    public var size = V3(2.5, 0.82, 0.68)
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        // Brief materials: metal.powdercoat vinyl.medical plastic.black plastic.matte laminate.white metal.chrome. Gate: realityhd gate beam-seating. Boards: plank()/board() along +X (grain on U).
        // Turned parts: turned(). Bevel every hard edge; jitter assembled parts.
        m.add(Prim.roundedBox(size, radius: 0.01, bevelSegments: 2, material: "metal.powdercoat"),
              Xform(translation: V3(0, size.y / 2, 0)).jittered(&rng))
        groundAO(&m)
        return LODModel(m)
    }
}
