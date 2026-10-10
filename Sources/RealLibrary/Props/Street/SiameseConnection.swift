import simd
import Foundation

/// Freestanding fire department siamese connection, 1.1 m tall: red standpipe riser, brass Y body, two 65 mm swivel couplings with caps, ID plate.
public struct SiameseConnection: RealAsset {
    public static let id = "siamese-connection"
    public static let summary = "Fire department siamese connection, 1.1 m: red riser on a concrete pad, brass Y body, two capped couplings, ID plate."
    public static let tags = ["prop", "street", "urban", "architecture", "metal"]
    public static let budget = 2600
    public static let author = "hunterh37"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        K.box(&m, V3(0, 0.04, 0), V3(0.7, 0.08, 0.5), "concrete.rough", bevel: 0.01)
        cy(&m, 0.09, 0.62, V3(0, 0.08, 0), "metal.painted:B3201C", bevel: 0.008, seg: 20)
        cy(&m, 0.11, 0.03, V3(0, 0.08, 0), "metal.painted:B3201C", bevel: 0.006, seg: 20)
        K.rod(&m, [V3(0, 0.7, 0), V3(0, 0.85, 0)], r: 0.075, "metal.brass", sides: 16)
        for s: Float in [-1, 1] {
            let a = V3(0, 0.85, 0), b = V3(s * 0.2, 1.0, 0.08)
            K.rod(&m, [a, b], r: 0.065, "metal.brass", sides: 16)
            K.rod(&m, [b, b + V3(s * 0.08, 0.0, 0.16)], r: 0.058, "metal.brass", sides: 16)
            let c = b + V3(s * 0.08, 0.0, 0.16)
            K.rod(&m, [c, c + V3(s * 0.02, 0, 0.06)], r: 0.075, "metal.brass-aged", sides: 16)
            K.rod(&m, [c + V3(s * 0.02, 0, 0.06), c + V3(s * 0.02, 0, 0.075)], r: 0.082, "metal.brass-aged", sides: 16)
            for k in 0..<3 {
                let a2 = Float(k) * 2.094
                K.box(&m, c + V3(s * 0.02 + cos(a2) * 0.08, sin(a2) * 0.08, 0.04), V3(0.03, 0.03, 0.02), "metal.brass-aged", bevel: 0.004)
            }
        }
        K.box(&m, V3(0, 0.55, 0.095), V3(0.2, 0.1, 0.006), "metal.brass", bevel: 0.002)
        K.box(&m, V3(0, 0.55, 0.099), V3(0.16, 0.05, 0.003), "metal.painted:8F1D1A", bevel: 0.001)
        return K.finish(&m, ao: 0.1)
    }
}
