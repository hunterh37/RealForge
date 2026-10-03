import simd
import Foundation

public struct Bollard: RealAsset {
    public static let id = "bollard"
    public static let summary = "Cast concrete bollard with domed top and chamfered base."
    public static let tags = ["prop", "urban", "concrete"]
    public static let budget = 3_000
    public init() {}
    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        var prof: [(Float, Float)] = [(0, 0), (0.15, 0), (0.15, 0.03), (0.13, 0.06), (0.12, 0.75)]
        for i in 1...8 { let a = Float(i) / 8 * .pi / 2; prof.append((0.12 * cos(a), 0.75 + 0.07 * sin(a))) }
        m.add(turned(prof, segments: 40, material: "concrete.rough", seamTile: 0.75))
        groundAO(&m, height: 0.2, floor: 0.55)
        return LODModel(m)
    }
}
