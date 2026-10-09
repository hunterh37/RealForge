import simd
import Foundation

/// 0.44 m square base tapering to the apex at 1.8 m.
public struct GardenObelisk: RealAsset {
    public static let id = "garden-obelisk"
    public static let summary = "Garden obelisk trellis, 1.9 m: four cedar legs leaning to a ball finial with square rungs at five heights."
    public static let tags = ["prop", "landscaping", "garden", "outdoor", "decor", "wood"]
    public static let budget = 4000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 35, elevation: 18)
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let wood = "wood.cedar-weathered", top = V3(0, 1.8, 0)
        let corners: [V3] = [V3(-1, 0, -1), V3(1, 0, -1), V3(1, 0, 1), V3(-1, 0, 1)]
        for c in corners { K.beam(&m, c * 0.22, top, 0.04, 0.04, wood, up: V3(c.x, 0, -c.z)) }
        for y: Float in [0.15, 0.55, 0.9, 1.2, 1.5] {
            let k: Float = 0.22 * (1 - y / 1.8)
            for i in 0..<4 {
                let a = corners[i] * k, b = corners[(i + 1) % 4] * k
                K.slat(&m, V3(a.x, y, a.z), V3(b.x, y, b.z), 0.022, 0.016, wood)
            }
        }
        m.add(Prim.superellipsoid(V3(0.08, 0.08, 0.08), exponent: 2, subdivisions: 6, material: wood), Xform(translation: V3(0, 1.84, 0)))
        return K.finish(&m)
    }
}
