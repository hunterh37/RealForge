import simd
import Foundation

/// Two 120 mm round posts 2.0 m apart, three 90 mm rails 2.6 m long.
public struct SplitRailFence: RealAsset {
    public static let id = "split-rail-fence"
    public static let summary = "Split-rail fence section, 2.6 m: two round posts with three tapered rails slotted through, weathered cedar."
    public static let tags = ["prop", "landscaping", "garden", "outdoor", "fence", "wood"]
    public static let budget = 5000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 35, elevation: 18)
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let wood = "wood.cedar-weathered"
        for s: Float in [-1, 1] {
            m.add(Prim.cylinder(radius: 0.06, height: 1.1, bevel: 0.02, segments: 12, material: wood, grainVertical: true), Xform(translation: V3(s * 1.0, 0, 0)))
        }
        for (i, y) in [Float(0.3), 0.65, 0.97].enumerated() {
            let dy = rng.float(-0.01...0.01), ofs: Float = i % 2 == 0 ? 0.02 : -0.02
            K.rod(&m, [V3(-1.3, y + dy, ofs), V3(1.3, y - dy, ofs)], r: 0.045, wood, sides: 10)
        }
        return K.finish(&m)
    }
}
