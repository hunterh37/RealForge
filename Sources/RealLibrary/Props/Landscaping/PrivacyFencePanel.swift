import simd
import Foundation

/// Twelve 140 mm boards with 12 mm gaps on 90x40 mm rails, 100 mm posts with caps.
public struct PrivacyFencePanel: RealAsset {
    public static let id = "privacy-fence-panel"
    public static let summary = "Privacy fence panel, 1.83 m wide and 1.8 m high: dog-eared cedar boards on three rails between 100 mm posts."
    public static let tags = ["prop", "landscaping", "garden", "outdoor", "fence", "wood"]
    public static let budget = 8000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 35, elevation: 18)
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let wood = "wood.cedar-weathered"
        let n = 12, pitch: Float = 1.83 / Float(n), w: Float = pitch - 0.012
        for i in 0..<n {
            let x = -0.915 + pitch * (Float(i) + 0.5), len: Float = 1.8 + rng.float(-0.004...0.004)
            let b = Prim.extrude(Shape2D.rounded([V2(-w / 2, 0), V2(w / 2, 0), V2(w / 2, len - 0.03), V2(w / 2 - 0.03, len), V2(-w / 2 + 0.03, len), V2(-w / 2, len - 0.03)], radius: 0.002),
                                 depth: 0.018, bevel: 0.002, material: wood)
            m.add(b, Xform(translation: V3(x, 0.05, rng.float(-0.002...0.002))))
        }
        for y: Float in [0.3, 0.9, 1.5] { K.box(&m, V3(0, y, -0.03), V3(1.83, 0.09, 0.04), wood) }
        for s: Float in [-1, 1] {
            K.box(&m, V3(s * 0.96, 1.0, -0.04), V3(0.1, 2.0, 0.1), wood)
            K.box(&m, V3(s * 0.96, 2.015, -0.04), V3(0.13, 0.03, 0.13), wood)
        }
        return K.finish(&m)
    }
}
