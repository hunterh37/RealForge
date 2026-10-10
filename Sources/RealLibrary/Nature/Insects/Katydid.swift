import simd
import Foundation

/// Greater angle-wing katydid (Microcentrum rhombifolium), 5 cm: leaf-green, broad leaf-shaped tegmina with a midrib and side veins held roof-wise, hair-thin antennae longer than the body, slender hind legs.
public struct Katydid: RealArticulated {
    public static let id = "insect-katydid"
    public static let summary = "Katydid, 5 cm: leaf-green, leaf-veined tegmina held roof-wise, hair-thin long antennae, slender hind legs; articulated."
    public static let tags = ["nature", "insect", "jumping", "flying", "articulated"]
    public static let budget = 14_000
    public static let preview = PreviewHint(azimuth: 40, elevation: 25, distance: 1.0, ground: false, studio: true)
    public init() {}

    public func rig(seed: UInt64) -> Rig {
        var s = InsectKit.Orthoptera()
        s.k = 1.0; s.body = "insect.chitin-soft:6FA548"; s.pronotum = "insect.chitin-soft:6A9E44"; s.legs = "insect.chitin-soft:7AAE50"
        s.tegmen = "insect.tegmen-katydid"; s.tegmenShape = .katydidTegmen; s.roof = 0.85; s.tegmenLength = 0.046; s.tegmenWidth = 0.012
        s.antennaLength = 0.075; s.antennaRadius = 0.00014; s.hindFemur = 0.020; s.hindBulge = 1.5; s.abdomenLength = 0.008
        s.hindMembrane = "insect.membrane"
        return InsectKit.assemble(InsectKit.orthoptera(Self.id, s))
    }
}
