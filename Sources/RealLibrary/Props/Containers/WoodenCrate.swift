import simd
import Foundation

public struct WoodenCrate: RealAsset {
    public static let id = "wooden-crate"
    public static let summary = "Slatted pine crate with corner posts, gapped boards, beveled edges."
    public static let tags = ["prop", "wood", "container"]
    public static let budget = 8_000
    public var size: V3 = V3(0.6, 0.45, 0.4)
    public var material: MaterialKey = "wood.pine"
    public init() {}
    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let h = size / 2, t: Float = 0.016, post: Float = 0.04
        let slats = 3, gap: Float = 0.012
        let slatH = (size.y - gap * Float(slats - 1)) / Float(slats)
        for i in 0..<slats {
            let y = slatH / 2 + Float(i) * (slatH + gap)
            for z in [-h.z + t / 2, h.z - t / 2] {   // long sides
                m.add(plank(size.x - 0.004, slatH, t, material: material), Xform(translation: V3(0, y, z), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))).jittered(&rng))
            }
            for x in [-h.x + t / 2, h.x - t / 2] {   // short sides
                m.add(plank(size.z - 2 * t, slatH, t, material: material), Xform(translation: V3(x, y, 0), rotation: simd_quatf(degrees: 90, axis: V3(0, 1, 0)) * simd_quatf(degrees: 90, axis: V3(1, 0, 0))).jittered(&rng))
            }
        }
        for sx: Float in [-1, 1] { for sz: Float in [-1, 1] {   // corner posts inside
            m.add(plank(size.y, post, post, material: material),
                  Xform(translation: V3(sx * (h.x - t - post / 2), h.y, sz * (h.z - t - post / 2)), rotation: simd_quatf(degrees: 90, axis: V3(0, 0, 1))))
        }}
        // Bottom boards.
        for k in 0..<4 {
            let z = -h.z + t + (Float(k) + 0.5) * (size.z - 2 * t) / 4
            m.add(plank(size.x - 2 * t, (size.z - 2 * t) / 4 - 0.006, t, material: material), Xform(translation: V3(0, t / 2, z)))
        }
        groundAO(&m, height: 0.1, floor: 0.6)
        return LODModel(m)
    }
}
