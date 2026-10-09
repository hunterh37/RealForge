import simd
import Foundation

/// 1.2 m wide, three treads of 340 mm, total rise 0.45 m.
public struct GardenSteps: RealAsset {
    public static let id = "garden-steps"
    public static let summary = "Sandstone garden steps, 0.45 m: three solid blocks 1.2 m wide rising 150 mm each with 340 mm treads."
    public static let tags = ["prop", "landscaping", "garden", "outdoor", "stone"]
    public static let budget = 3000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 35, elevation: 18)
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        for i in 0..<3 {
            let h: Float = 0.15 * Float(i + 1) - 0.004 * Float(i)
            m.add(Prim.roundedBox(V3(1.2, h, 0.34), radius: 0.008, bevelSegments: 2, material: "stone.sandstone"),
                  Xform(translation: V3(rng.float(-0.004...0.004), h / 2, -0.34 * Float(i))))
        }
        return K.finish(&m)
    }
}
