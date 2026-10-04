import simd
import Foundation

/// Check-in Kiosk: New hospital lobby kiosk: clean white, the card reader bezel worn grey by fingers.. Parts: weighted oval steel base plate, slim column with cable cover, angled head housing with 21.5-inch touchscreen, EMV card reader with contactless pad, receipt printer slot with paper that slides out, flatbed ID scanner under a hinged lid, privacy hood and logo strip, speaker grille and status LED.
public struct CheckInKiosk: RealAsset {
    public static let id = "check-in-kiosk"
    public static let summary = "Freestanding patient check-in kiosk: oval base, slim column, angled 21.5-inch touchscreen, card reader, receipt printer and ID scanner."
    public static let tags = ["prop", "medical", "hospital", "interior", "electronics", "metal", "plastic", "articulated"]
    public static let budget = 9000
    public static let author = "realityhd"

    /// Overall size in meters (x width, y height, z depth). Expose every knob a scene might tune.
    public var size = V3(0.56, 1.5, 0.56)
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        // Brief materials: metal.powder-white plastic.medical-grey screen.off screen.ui plastic.black paper.sheet. Gate: realityhd gate check-in-kiosk. Boards: plank()/board() along +X (grain on U).
        // Turned parts: turned(). Bevel every hard edge; jitter assembled parts.
        m.add(Prim.roundedBox(size, radius: 0.01, bevelSegments: 2, material: "metal.powder-white"),
              Xform(translation: V3(0, size.y / 2, 0)).jittered(&rng))
        groundAO(&m)
        return LODModel(m)
    }
}
