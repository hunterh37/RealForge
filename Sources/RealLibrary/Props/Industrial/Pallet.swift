import simd
import Foundation

public struct Pallet: RealAsset {
    public static let id = "pallet"
    public static let summary = "EUR pallet (1.2 x 0.8 m): deck boards, blocks, bottom runners, rough pine."
    public static let tags = ["prop", "wood", "industrial"]
    public static let budget = 10_000
    public init() {}
    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let w: MaterialKey = "wood.weathered"
        for z: Float in [-0.35, 0, 0.35] { m.add(plank(1.2, 0.1, 0.022, material: w), Xform(translation: V3(0, 0.011, z)).jittered(&rng)) }
        for x: Float in [-0.545, 0, 0.545] { for z: Float in [-0.35, 0, 0.35] {
            m.add(Prim.roundedBox(V3(0.1, 0.078, z == 0 ? 0.145 : 0.1), radius: 0.004, material: w), Xform(translation: V3(x, 0.022 + 0.039, z)).jittered(&rng))
        }}
        for x: Float in [-0.545, 0, 0.545] { m.add(plank(0.8, 0.1, 0.022, material: w), Xform(translation: V3(x, 0.111, 0), rotation: simd_quatf(degrees: 90, axis: .up)).jittered(&rng)) }
        for (i, z) in ([-0.35, -0.2, -0.0, 0.2, 0.35] as [Float]).enumerated() {
            m.add(plank(1.2, i % 2 == 0 ? 0.145 : 0.1, 0.022, material: w), Xform(translation: V3(0, 0.133, z)).jittered(&rng))
        }
        groundAO(&m, height: 0.1, floor: 0.6)
        return LODModel(m)
    }
}
