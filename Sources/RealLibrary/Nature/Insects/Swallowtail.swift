import simd
import Foundation

/// Eastern tiger swallowtail (Papilio glaucus), 11 cm span: yellow wings with black tiger stripes and borders, blue and orange hindwing spots, long tails.
public struct Swallowtail: RealArticulated {
    public static let id = "insect-swallowtail"
    public static let summary = "Tiger swallowtail, 11 cm span: yellow wings with black stripes, blue-orange hindwing spots and tails; articulated."
    public static let tags = ["nature", "insect", "flying", "articulated"]
    public static let budget = 12_000
    public static let preview = PreviewHint(azimuth: 20, elevation: 50, distance: 1.0, ground: false, studio: true)
    public init() {}

    public func rig(seed: UInt64) -> Rig {
        var s = InsectKit.Lepidoptera(fore: (.swallowtailFore, "insect.wing-swallowtail-fore", length: 0.052, width: 0.030, rootV: 0.62), hind: (.swallowtailHind, "insect.wing-swallowtail-hind", length: 0.040, width: 0.046, rootV: 0.78))
        s.thorax = "insect.fur:2A2416"; s.abdomen = "insect.fur:D8B840"; s.thoraxSpots = nil; s.reducedForelegs = false; s.hindSweep = -0.25
        return InsectKit.assemble(InsectKit.lepidoptera(Self.id, s))
    }
}
