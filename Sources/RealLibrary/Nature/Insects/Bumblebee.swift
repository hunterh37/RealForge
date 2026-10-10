import simd
import Foundation

/// Buff-tailed bumblebee (Bombus terrestris), 2 cm: plump and densely furred, yellow collar,
/// black thorax, yellow second abdominal band and white tail, smoky veined wings.
public struct Bumblebee: RealArticulated {
    public static let id = "insect-bumblebee"
    public static let summary = "Bumblebee, 2 cm: plump furred body, yellow collar and band, white tail, smoky wings; articulated wings, legs, antennae."
    public static let tags = ["nature", "insect", "flying", "articulated"]
    public static let budget = 12_000
    public static let preview = PreviewHint(azimuth: 40, elevation: 28, distance: 1.0, ground: false, studio: true)
    public init() {}

    public func rig(seed: UInt64) -> Rig {
        var s = InsectKit.Bee()
        s.k = 1.35; s.plump = 1.3
        s.head = "insect.fur:1E1C1A"; s.collar = "insect.fur:E8B830"; s.thorax = "insect.fur:1E1C1A"
        s.bands = ["insect.fur:1E1C1A", "insect.fur:E8B830", "insect.fur:1E1C1A", "insect.fur:1E1C1A", "insect.fur:EDEBE4", "insect.fur:E8E6DE"]
        s.membrane = "insect.membrane-smoky"; s.legs = "insect.fur:1E1C1A"
        return InsectKit.assemble(InsectKit.bee(Self.id, s))
    }
}
