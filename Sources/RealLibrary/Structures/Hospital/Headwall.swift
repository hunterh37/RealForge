import simd
import Foundation

/// Patient Headwall: In-service ward headwall: clean anodized finish, a fresh O2-in-use tag, canister slightly fogged.. Parts: clear anodized horizontal extrusion with end caps, integrated overbed luminaire with up-light slot and reading and exam down-light lenses, medical gas outlets O2 (green), air (yellow), vacuum (white) with ID plates, hospital-grade duplex receptacles on red (emergency) and white plates, nurse call station with call and cancel buttons, pillow speaker jack and hook, equipment rail along the bottom, wall suction regulator with gauge plugged into the vacuum outlet, 1200 cc suction canister with blue lid on a rail bracket and tubing, light rocker switches.
public struct Headwall: RealAsset {
    public static let id = "headwall"
    public static let summary = "Patient-room headwall: 2.4 m aluminium extrusion with O2, air and vacuum outlets, outlets, nurse call, overbed up/down light and suction canister."
    public static let tags = ["structure", "medical", "hospital", "interior", "metal", "electronics", "light", "articulated"]
    public static let budget = 20000
    public static let author = "realityhd"

    /// Overall size in meters (x width, y height, z depth). Expose every knob a scene might tune.
    public var size = V3(2.4, 0.72, 0.2)
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        // Brief materials: metal.anodized metal.powder-white plastic.medical plastic.diffuser emissive.panel metal.chrome plastic.clear label.hazard. Gate: realityhd gate headwall. Boards: plank()/board() along +X (grain on U).
        // Turned parts: turned(). Bevel every hard edge; jitter assembled parts.
        m.add(Prim.roundedBox(size, radius: 0.01, bevelSegments: 2, material: "metal.anodized"),
              Xform(translation: V3(0, size.y / 2, 0)).jittered(&rng))
        groundAO(&m)
        return LODModel(m)
    }
}
