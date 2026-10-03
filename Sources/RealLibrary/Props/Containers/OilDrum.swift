import simd
import Foundation

public struct OilDrum: RealAsset {
    public static let id = "oil-drum"
    public static let summary = "55-gallon steel drum, rolling ribs, painted with chips and scratches."
    public static let tags = ["prop", "metal", "container", "industrial"]
    public static let budget = 6_000
    public var color: UInt32 = 0x1F4E8C
    public init() {}
    public func build(seed: UInt64) -> LODModel {
        let r: Float = 0.286, h: Float = 0.88
        var prof: [(Float, Float)] = [(0, 0.004), (r - 0.01, 0.0), (r, 0.012), (r - 0.004, 0.02)]
        for y in [0.29, 0.59] as [Float] {
            prof += [(r - 0.004, y * h - 0.02), (r + 0.006, y * h - 0.008), (r + 0.006, y * h + 0.008), (r - 0.004, y * h + 0.02)]
        }
        prof += [(r - 0.004, h - 0.02), (r, h - 0.012), (r - 0.01, h), (r - 0.018, h - 0.006), (0, h - 0.006)]
        let key = String(format: "metal.painted:%06X", color)
        var m = Model(name: Self.id, surfaces: [turned(prof, segments: 56, material: key, seamTile: 0.45)])
        // Bung caps.
        m.add(turned([(0, 0), (0.025, 0), (0.025, 0.008), (0, 0.01)], segments: 12, material: "metal.steel"), Xform(translation: V3(0.15, h - 0.006, 0.05)))
        groundAO(&m, height: 0.15, floor: 0.55)
        return LODModel(m)
    }
}
