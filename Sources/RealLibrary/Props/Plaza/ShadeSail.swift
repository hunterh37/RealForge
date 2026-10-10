import simd
import Foundation

/// Tensioned shade sail on four steel posts, 4 m by 3 m: low edge 2.6 m, high edge 3.4 m, canvas panel, corner rings.
public struct ShadeSail: RealAsset {
    public static let id = "shade-sail"
    public static let summary = "Shade sail, 4 x 3 m: four steel posts, tilted canvas panel with hem tape and corner rings."
    public static let tags = ["prop", "park", "outdoor", "fabric", "metal"]
    public static let budget = 4900
    public static let author = "hunterh37"

    /// Panel material key.
    public var fabric = "fabric.canvas"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let W: Float = 4.0, D: Float = 3.0, lo: Float = 2.6, hi: Float = 3.4
        for (x, z, h) in [(-W / 2, D / 2, lo), (W / 2, D / 2, lo), (-W / 2, -D / 2, hi), (W / 2, -D / 2, hi)] {
            cy(&m, 0.06, h + 0.1, V3(x, 0, z), "metal.galvanized", bevel: 0.008, seg: 20)
            cy(&m, 0.12, 0.03, V3(x, 0, z), "metal.galvanized", bevel: 0.006, seg: 20)
        }
        let len = simd_length(V3(0, hi - lo, D)), ang = atan2(hi - lo, D) * 180 / .pi
        let mid = V3(0, (hi + lo) / 2 + 0.05, 0)
        let rot = simd_quatf(degrees: ang, axis: V3(1, 0, 0))
        m.add(Prim.roundedBox(V3(W - 0.3, 0.008, len - 0.3), radius: 0.003, bevelSegments: 1, material: MaterialKey(stringLiteral: fabric)), Xform(translation: mid, rotation: rot))
        for (x, z, h) in [(-W / 2, D / 2, lo), (W / 2, D / 2, lo), (-W / 2, -D / 2, hi), (W / 2, -D / 2, hi)] {
            let sx: Float = x < 0 ? 1 : -1, sz: Float = z < 0 ? 1 : -1
            m.add(Prim.torus(major: 0.035, minor: 0.008, segments: 16, sides: 8, material: "metal.steel"),
                  Xform(translation: V3(x + sx * 0.06, h + 0.05, z + sz * 0.06), rotation: simd_quatf(degrees: 90, axis: V3(0, 0, 1))))
        }
        return K.finish(&m, ao: 0.1)
    }
}
