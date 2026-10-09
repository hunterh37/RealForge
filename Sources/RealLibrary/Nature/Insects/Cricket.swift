import simd
import Foundation

/// Field cricket (Gryllus pennsylvanicus) male, 2.5 cm: glossy black, round head, long antennae, short net-veined tegmina for chirping, long cerci, stout jumping hind legs.
public struct Cricket: RealArticulated {
    public static let id = "insect-cricket"
    public static let summary = "Field cricket, 2.5 cm: glossy black body, round head, long antennae, veined tegmina, cerci, jumping legs; articulated."
    public static let tags = ["nature", "insect", "jumping", "articulated"]
    public static let budget = 14_000
    public static let preview = PreviewHint(azimuth: 40, elevation: 25, distance: 1.0, ground: false, studio: true)
    public init() {}

    public func rig(seed: UInt64) -> Rig {
        var s = InsectKit.Orthoptera()
        s.k = 0.68; s.body = "insect.chitin:1A1614"; s.pronotum = "insect.chitin:1E1A16"; s.legs = "insect.chitin:2A2018"
        s.tegmen = "insect.tegmen-cricket"; s.roof = 0.25; s.tegmenLength = 0.016; s.tegmenWidth = 0.0055; s.antennaLength = 0.032; s.antennaRadius = 0.0002
        s.headRound = 0.95; s.cerci = true; s.hindFemur = 0.015; s.hindBulge = 2.2; s.abdomenLength = 0.009
        return InsectKit.assemble(InsectKit.orthoptera(Self.id, s))
    }
}
