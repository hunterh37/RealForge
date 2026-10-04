import simd
import Foundation

/// Sterilization instrument container: hospital SPD full-size container (Aesculap SterilContainer JK class), satin anodized, scuffed corners, yellow tamper seals and a load card.. Parts: ribbed anodized aluminium tub, 580 x 280 mm, blue anodized lid with two round filter retention plates, folding carry handles on the short ends, two lever latches on the ends with tamper seals, aluminium ID tag on the end, wire mesh basket with instruments inside.
public struct InstrumentContainer: RealAsset {
    public static let id = "instrument-container"
    public static let summary = "Rigid sterilization container: anodized aluminium tub, blue lid with filter plates, side latches with seals and a perforated instrument basket."
    public static let tags = ["prop", "medical", "surgical", "articulated", "container", "metal", "handheld"]
    public static let budget = 8000
    public static let author = "realityhd"

    /// Overall size in meters (x width, y height, z depth). Expose every knob a scene might tune.
    public var size = V3(0.6, 0.152, 0.285)
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        // Brief materials: metal.anodized metal.anodized:2E5C9E metal.surgical label.rx plastic.medical. Gate: realityhd gate instrument-container. Boards: plank()/board() along +X (grain on U).
        // Turned parts: turned(). Bevel every hard edge; jitter assembled parts.
        m.add(Prim.roundedBox(size, radius: 0.01, bevelSegments: 2, material: "metal.anodized"),
              Xform(translation: V3(0, size.y / 2, 0)).jittered(&rng))
        groundAO(&m)
        return LODModel(m)
    }
}
