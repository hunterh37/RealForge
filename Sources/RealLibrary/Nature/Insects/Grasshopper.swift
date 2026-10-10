import simd
import Foundation

/// Differential grasshopper (Melanoplus differentialis), 4 cm: olive-green body, mottled brown tegmina, short antennae, powerful hind legs with chevron-ridged femora and spined tibiae.
public struct Grasshopper: RealArticulated {
    public static let id = "insect-grasshopper"
    public static let summary = "Grasshopper, 4 cm: olive body, mottled tegmina, chevron-ridged jumping hind legs, short antennae; articulated."
    public static let tags = ["nature", "insect", "jumping", "flying", "articulated"]
    public static let budget = 14_000
    public static let preview = PreviewHint(azimuth: 40, elevation: 25, distance: 1.0, ground: false, studio: true)
    public init() {}

    public func rig(seed: UInt64) -> Rig {
        var s = InsectKit.Orthoptera()
        s.body = "insect.chitin-soft:8A9A4A"; s.pronotum = "insect.chitin-soft:7A8A40"; s.legs = "insect.chitin-soft:8A9450"
        return InsectKit.assemble(InsectKit.orthoptera(Self.id, s))
    }
}
