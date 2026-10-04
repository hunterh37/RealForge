import simd
import Foundation

/// Automated external defibrillator: Public-access AED (ZOLL AED Plus / Philips HeartStart class), lightly worn bumpers.. Parts: two-shell green case with rubber bumpers, molded carry handle at the back, flip-up lid hinged at the back, electrode pad package and cable stowed under the lid (out option), status LCD and readiness indicator, flashing shock button and on/off button, speaker grille and pictogram label.
public struct Aed: RealAsset {
    public static let id = "aed"
    public static let summary = "Automated external defibrillator: molded green case with carry handle, flip-up lid stowing electrode pads, status LCD, shock button and speaker."
    public static let tags = ["prop", "medical", "articulated", "handheld", "electronics", "hospital", "plastic"]
    public static let budget = 5500
    public static let author = "realityhd"

    /// Overall size in meters (x width, y height, z depth). Expose every knob a scene might tune.
    public var size = V3(0.241, 0.133, 0.292)
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        // Brief materials: plastic.medical plastic.medical-grey rubber screen.off screen.lcd emissive.led-red label.hazard. Gate: realityhd gate aed. Boards: plank()/board() along +X (grain on U).
        // Turned parts: turned(). Bevel every hard edge; jitter assembled parts.
        m.add(Prim.roundedBox(size, radius: 0.01, bevelSegments: 2, material: "plastic.medical"),
              Xform(translation: V3(0, size.y / 2, 0)).jittered(&rng))
        groundAO(&m)
        return LODModel(m)
    }
}
