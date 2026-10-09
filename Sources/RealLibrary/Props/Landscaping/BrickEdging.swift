import simd
import Foundation

/// Bricks 215 mm by 100 mm by 65 mm, 12 per metre.
public struct BrickEdging: RealAsset {
    public static let id = "brick-edging"
    public static let summary = "Brick edging, 0.22 m: red bricks set on end at 45 degrees in a sawtooth row, 1.0 m long."
    public static let tags = ["prop", "landscaping", "garden", "outdoor", "brick"]
    public static let budget = 3500
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 35, elevation: 18)
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let n = 12
        for i in 0..<n {
            let x: Float = -0.5 + 0.0833 * (Float(i) + 0.5)
            m.add(Prim.roundedBox(V3(0.065, 0.215, 0.1), radius: 0.004, bevelSegments: 1, material: "brick.red"),
                  Xform(translation: V3(x, 0.1, 0), rotation: simd_quatf(degrees: -42 + rng.float(-2...2), axis: V3(0, 0, 1)) * simd_quatf(degrees: rng.float(-1.5...1.5), axis: .up)))
        }
        return K.finish(&m)
    }
}
