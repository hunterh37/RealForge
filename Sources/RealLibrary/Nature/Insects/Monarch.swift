import simd
import Foundation

/// Monarch butterfly (Danaus plexippus), 10 cm span: orange wings with black veins and white-dotted black borders, black body with white spots, reduced forelegs. Rests with wings closed.
public struct Monarch: RealArticulated {
    public static let id = "insect-monarch"
    public static let summary = "Monarch butterfly, 10 cm span: orange wings, black veins, white-dotted borders; articulated wings, legs, antennae."
    public static let tags = ["nature", "insect", "flying", "articulated"]
    public static let budget = 12_000
    public static let preview = PreviewHint(azimuth: 20, elevation: 50, distance: 1.0, ground: false, studio: true)
    public init() {}

    public func rig(seed: UInt64) -> Rig {
        var s = InsectKit.Lepidoptera(fore: (.monarchFore, "insect.wing-monarch-fore", length: 0.049, width: 0.031, rootV: 0.6), hind: (.monarchHind, "insect.wing-monarch-hind", length: 0.037, width: 0.034, rootV: 0.66))
        
        return InsectKit.assemble(InsectKit.lepidoptera(Self.id, s))
    }
}
