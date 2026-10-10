import simd
import Foundation

/// Open timber park pavilion, 4.2 m by 6.0 m and 3.4 m tall: six square posts, beams, gable roof of standing-seam metal, concrete pad, two picnic tables.
public struct ParkPavilion: RealAsset {
    public static let id = "park-pavilion"
    public static let summary = "Open park pavilion, 4.2 x 6 m: six timber posts, beams, gable standing-seam roof, slab floor, two picnic tables."
    public static let tags = ["prop", "park", "outdoor", "wood", "architecture"]
    public static let budget = 5400
    public static let author = "hunterh37"

    /// Roof panel color, sRGB hex.
    public var roofColor: UInt32 = 0x4F6D5A
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let w: Float = 4.2, d: Float = 6.0, h: Float = 2.6
        K.box(&m, V3(0, 0.06, 0), V3(w + 0.4, 0.12, d + 0.4), "concrete.sidewalk", bevel: 0.01)
        for x: Float in [-w / 2, w / 2] {
            for z: Float in [-d / 2, 0, d / 2] { K.box(&m, V3(x, 0.12 + h / 2, z), V3(0.2, h, 0.2), "wood.cedar-weathered", bevel: 0.01) }
            K.box(&m, V3(x, 0.12 + h + 0.12, 0), V3(0.18, 0.24, d + 0.5), "wood.cedar-weathered", bevel: 0.008)
        }
        let ridge: Float = 0.12 + h + 0.24 + 1.0
        for z: Float in [-d / 2, 0, d / 2] {
            K.box(&m, V3(0, 0.12 + h + 0.3, z), V3(w + 0.1, 0.14, 0.16), "wood.cedar-weathered", bevel: 0.008)
            for s: Float in [-1, 1] { K.beam(&m, V3(s * (w / 2 + 0.4), 0.12 + h + 0.3, z), V3(0, ridge - 0.08, z), 0.12, 0.1, "wood.cedar-weathered") }
        }
        let roofMat = SK.paint(roofColor)
        for s: Float in [-1, 1] {
            let a = V3(s * (w / 2 + 0.55), 0.12 + h + 0.28, 0), b = V3(0, ridge + 0.03, 0)
            let dir = b - a, len = simd_length(dir), ang = atan2(dir.y, abs(dir.x)) * s * -1
            K.box(&m, (a + b) / 2 + V3(0, 0.07, 0), V3(len, 0.04, d + 0.8), roofMat, bevel: 0.006, rot: simd_quatf(angle: ang, axis: V3(0, 0, 1)))
        }
        K.box(&m, V3(0, ridge + 0.1, 0), V3(0.3, 0.06, d + 0.8), roofMat, bevel: 0.01)
        for z: Float in [-1.4, 1.4] {
            K.box(&m, V3(0, 0.82, z), V3(0.7, 0.05, 2.0), "wood.cedar-weathered", bevel: 0.006)
            for x: Float in [-0.7, 0.7] { K.box(&m, V3(x, 0.45, z), V3(0.35 , 0.05, 2.0), "wood.cedar-weathered", bevel: 0.006) }
            for zz: Float in [-0.8, 0.8] { K.box(&m, V3(0, 0.42, z + zz), V3(1.9, 0.07, 0.07), "wood.cedar-weathered", bevel: 0.005) }
        }
        return K.finish(&m, ao: 0.3)
    }
}
