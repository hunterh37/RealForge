import simd
import Foundation

/// Fixed steel access ladder with safety cage, 4.2 m tall: flat-bar rails, 300 mm rungs, hoop cage with vertical bars, wall brackets, top grab bars.
public struct CageLadder: RealAsset {
    public static let id = "cage-ladder"
    public static let summary = "Fixed steel ladder with safety cage, 4.2 m: flat-bar rails, 300 mm rungs, hoop cage, wall brackets, grab bars."
    public static let tags = ["prop", "roof", "industrial", "building", "metal"]
    public static let budget = 2300
    public static let author = "hunterh37"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let H: Float = 4.2, hw: Float = 0.2, steel = "metal.galvanized", off: Float = 0.18
        for s: Float in [-1, 1] { K.box(&m, V3(s * hw, H / 2, 0), V3(0.05, H, 0.012), steel, bevel: 0.002) }
        var y: Float = 0.3
        while y < H - 0.1 {
            K.rod(&m, [V3(-hw, y, off * 0.0 + 0.02), V3(hw, y, 0.02)], r: 0.014, steel, sides: 8)
            y += 0.3
        }
        for y in [0.4, 2.0, 3.6] as [Float] {
            for s: Float in [-1, 1] { K.box(&m, V3(s * hw, y, -0.1), V3(0.04, 0.04, 0.2), steel, bevel: 0.003) }
        }
        let R: Float = 0.38
        var hy: Float = 2.2
        while hy <= H {
            var pts: [V3] = []
            for i in 0...14 {
                let a = (-0.5 + Float(i) / 14 * 1.0) * .pi * 1.55
                pts.append(V3(sin(a) * R, hy, 0.02 + cos(a) * R))
            }
            K.rod(&m, pts, r: 0.011, steel, sides: 6)
            hy += 0.75
        }
        for k in 0..<5 {
            let a = (-0.5 + Float(k) / 4) * .pi * 1.55
            K.rod(&m, [V3(sin(a) * R, 2.2, 0.02 + cos(a) * R), V3(sin(a) * R, H, 0.02 + cos(a) * R)], r: 0.009, steel, sides: 6)
        }
        for s: Float in [-1, 1] { K.rod(&m, [V3(s * hw, H - 0.1, 0.0), V3(s * hw, H + 0.45, 0.0), V3(s * hw, H + 0.45, -0.3)], r: 0.016, steel, sides: 8) }
        return K.finish(&m, ao: 0.1)
    }
}
