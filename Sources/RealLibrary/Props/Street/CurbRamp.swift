import simd
import Foundation

/// Accessible curb ramp, 1.5 m wide and 1.8 m long, 0.15 m curb drop (1:12 slope): concrete ramp, flanking curbs, yellow truncated-dome warning plate.
public struct CurbRamp: RealAsset {
    public static let id = "curb-ramp"
    public static let summary = "Accessible curb ramp, 1.5 x 1.8 m: 1:12 concrete slope, flanking curbs, yellow truncated-dome tactile plate."
    public static let tags = ["prop", "city", "street", "road", "urban", "concrete"]
    public static let budget = 7500
    public static let author = "hunterh37"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let w: Float = 1.5, L: Float = 1.8, drop: Float = 0.15
        SK.side(&m, [V2(-L / 2, 0), V2(L / 2, 0), V2(-L / 2, drop)], width: w, mat: "concrete.sidewalk", bevel: 0.004)
        for s: Float in [-1, 1] {
            K.box(&m, V3(s * (w / 2 + 0.45), drop / 2, 0), V3(0.9, drop, L), "concrete.sidewalk", bevel: 0.006)
        }
        K.box(&m, V3(0, drop / 2, -L / 2 - 0.3), V3(w, drop, 0.6), "concrete.sidewalk", bevel: 0.006)
        let slope = atan2(drop, L), rot = simd_quatf(angle: slope, axis: V3(1, 0, 0))
        let zc: Float = 0.55, yc = drop * (L / 2 - zc) / L + 0.008
        K.box(&m, V3(0, yc, zc), V3(1.2, 0.012, 0.6), "plastic.yellow", bevel: 0.002, rot: rot)
        for i in 0..<10 { for j in 0..<4 {
            let lz: Float = (Float(j) - 1.5) * 0.12
            let p = V3(-0.54 + Float(i) * 0.12, 0.011, lz)
            m.add(Prim.cylinder(radius: 0.012, height: 0.008, bevel: 0.002, segments: 8, material: "plastic.yellow"),
                  Xform(translation: V3(0, yc, zc) + rot.act(p), rotation: rot))
        } }
        return K.finish(&m, ao: 0.05)
    }
}
