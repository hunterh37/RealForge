import simd
import Foundation

/// Luna moth (Actias luna), 11 cm span: pale lime-green wings with maroon costal band, eyespots and long curved hindwing tails; white furry body, feathered antennae. Rests with wings spread.
public struct LunaMoth: RealArticulated {
    public static let id = "insect-luna-moth"
    public static let summary = "Luna moth, 11 cm span: pale green wings, eyespots, long hindwing tails, white furry body, feathered antennae; articulated."
    public static let tags = ["nature", "insect", "flying", "articulated"]
    public static let budget = 12_000
    public static let preview = PreviewHint(azimuth: 20, elevation: 50, distance: 1.0, ground: false, studio: true)
    public init() {}

    public func rig(seed: UInt64) -> Rig {
        var s = InsectKit.Lepidoptera(fore: (.lunaFore, "insect.wing-luna-fore", length: 0.050, width: 0.030, rootV: 0.6), hind: (.lunaHind, "insect.wing-luna-hind", length: 0.040, width: 0.060, rootV: 0.82))
        s.thorax = "insect.fur:EDE8D8"; s.abdomen = "insect.fur:E4DEC8"; s.thoraxSpots = nil; s.feathered = true; s.reducedForelegs = false; s.restWing = 0; s.hindSweep = -0.2
        return InsectKit.assemble(InsectKit.lepidoptera(Self.id, s))
    }
}
