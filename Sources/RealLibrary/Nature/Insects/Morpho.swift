import simd
import Foundation

/// Blue morpho (Morpho peleides), 14 cm span: iridescent structural-blue dorsal wings with black borders and white border spots, brown body.
public struct Morpho: RealArticulated {
    public static let id = "insect-morpho"
    public static let summary = "Blue morpho, 14 cm span: iridescent blue wings with black borders and white spots; articulated wings, legs, antennae."
    public static let tags = ["nature", "insect", "flying", "articulated"]
    public static let budget = 12_000
    public static let preview = PreviewHint(azimuth: 20, elevation: 50, distance: 1.0, ground: false, studio: true)
    public init() {}

    public func rig(seed: UInt64) -> Rig {
        var s = InsectKit.Lepidoptera(fore: (.morphoFore, "insect.wing-morpho-fore", length: 0.050, width: 0.032, rootV: 0.6), hind: (.morphoHind, "insect.wing-morpho-hind", length: 0.040, width: 0.036, rootV: 0.66))
        s.k = 1.32; s.thorax = "insect.fur:3A2E22"; s.abdomen = "insect.fur:4A3A2A"; s.thoraxSpots = nil
        return InsectKit.assemble(InsectKit.lepidoptera(Self.id, s))
    }
}
