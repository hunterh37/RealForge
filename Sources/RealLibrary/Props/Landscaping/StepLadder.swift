import simd
import Foundation

public struct StepLadder: RealAsset {
    public static let id = "step-ladder"
    public static let summary = "Aluminum step ladder, 1.2 m: four rungs, folding A-frame, rubber feet and paint shelf."
    public static let tags = ["prop", "landscaping", "tool", "metal"]
    public static let budget = 5000
    public static let author = "realityhd"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let al = "metal.aluminum-brushed"
        for s: Float in [-1, 1] {
            K.beam(&m, V3(s * 0.22, 0, 0.35), V3(s * 0.2, 1.2, 0.02), 0.045, 0.02, al, up: V3(1, 0, 0))
            K.beam(&m, V3(s * 0.2, 0, -0.35), V3(s * 0.18, 1.18, -0.02), 0.04, 0.02, al, up: V3(1, 0, 0))
        }
        for i in 1...4 {
            let t = Float(i) / 5, z = 0.35 - t * 0.33, x: Float = 0.22 - t * 0.02
            K.box(&m, V3(0, t * 1.2, z), V3(x * 2, 0.03, 0.08), al)
        }
        K.box(&m, V3(0, 1.2, 0), V3(0.44, 0.03, 0.3), "plastic.black")
        for s: Float in [-1, 1] { for z: Float in [-0.35, 0.35] { K.box(&m, V3(s * 0.22, 0.01, z), V3(0.05, 0.02, 0.05), "plastic.black") } }
        return K.finish(&m)
    }
}
