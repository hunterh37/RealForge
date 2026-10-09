import simd
import Foundation

/// Western honey bee worker (Apis mellifera), 14 mm: amber and dark-brown banded abdomen, tawny
/// hairy thorax, large compound eyes, elbowed antennae, clear veined wings folded over the abdomen.
public struct HoneyBee: RealArticulated {
    public static let id = "insect-honeybee"
    public static let summary = "Honey bee worker, 14 mm: amber-banded abdomen, hairy tawny thorax, veined clear wings; articulated wings, legs, antennae."
    public static let tags = ["nature", "insect", "flying", "articulated"]
    public static let budget = 12_000
    public static let preview = PreviewHint(azimuth: 40, elevation: 28, distance: 1.0, ground: false, studio: true)
    public init() {}

    public func rig(seed: UInt64) -> Rig {
        InsectKit.assemble(InsectKit.bee(Self.id, InsectKit.Bee()))
    }
}
