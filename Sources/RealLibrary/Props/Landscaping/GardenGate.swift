import simd
import Foundation

/// Painted picket gate, 1.0 m clear opening between two capped 100 mm posts, nine pointed pickets over two rails and a diagonal brace.
public struct GardenGate: RealAsset {
    public static let id = "garden-gate"
    public static let summary = "Painted picket garden gate, 1.1 m: pointed pickets on two rails with a Z-brace, strap hinges, thumb latch, capped posts."
    public static let tags = ["prop", "landscaping", "garden", "outdoor", "fence", "wood"]
    public static let budget = 6000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 35, elevation: 18)
    /// Paint color (sRGB hex).
    public var paint: UInt32 = 0xEDE8DA
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let wood = String(format: "wood.barn-white:%06X", paint)
        let iron = "metal.painted:2A2A2A"
        for s: Float in [-1, 1] {
            K.box(&m, V3(s * 0.55, 0.55, 0), V3(0.1, 1.1, 0.1), wood)
            K.box(&m, V3(s * 0.55, 1.115, 0), V3(0.13, 0.03, 0.13), wood)
        }
        K.box(&m, V3(0, 0.8, 0), V3(1.0, 0.08, 0.03), wood)
        K.box(&m, V3(0, 0.2, 0), V3(1.0, 0.08, 0.03), wood)
        K.beam(&m, V3(-0.45, 0.2, -0.026), V3(0.45, 0.8, -0.026), 0.07, 0.022, wood, up: V3(0, 0, 1))
        let n = 9, pitch: Float = 1.0 / Float(n), w: Float = 0.075
        for i in 0..<n {
            let x = -0.5 + pitch * (Float(i) + 0.5), len: Float = 0.84 + rng.float(-0.004...0.004)
            let p = Prim.extrude(Shape2D.rounded([V2(-w / 2, 0), V2(w / 2, 0), V2(w / 2, len - 0.035), V2(0, len), V2(-w / 2, len - 0.035)], radius: 0.004),
                                 depth: 0.018, bevel: 0.002, material: wood)
            m.add(p, Xform(translation: V3(x, 0.08, 0.027)))
        }
        for y: Float in [0.2, 0.8] { K.box(&m, V3(-0.39, y, 0.045), V3(0.22, 0.035, 0.008), iron, bevel: 0.002) }
        K.box(&m, V3(0.43, 0.5, 0.045), V3(0.07, 0.05, 0.012), iron, bevel: 0.002)
        K.box(&m, V3(0.39, 0.5, 0.054), V3(0.07, 0.012, 0.008), iron, bevel: 0.002)
        return K.finish(&m)
    }
}
