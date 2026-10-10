import simd
import Foundation

/// Retractable awning 1.8 x 1.1 m: striped canvas on a roller, scissor arms and valance bar.
public struct RetractableAwning: RealAsset {
    public static let id = "retractable-awning"
    public static let summary = "Retractable awning 1.8 x 1.1 m: striped canvas on a roller, scissor arms and valance bar."
    public static let tags = ["prop", "facade", "architecture", "fabric"]
    public static let budget = 3000
    public static let author = "hunterh37"

    /// Primary material key.
    public var material: String = "fabric.canvas"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let material = self.material
        let w: Float = 1.8, d: Float = 1.1, drop: Float = 0.4
        let ang = atan2(drop, d) * 180 / .pi, len = sqrt(d * d + drop * drop)
        m.add(Prim.cylinder(radius: 0.04, height: w, bevel: 0.004, segments: 16, material: "metal.aluminum-brushed"), Xform(translation: V3(-w / 2, 0.7, -d / 2), rotation: simd_quatf(degrees: -90, axis: V3(0, 0, 1))))
        for i in 0..<6 {
            let x0 = -w / 2 + w * Float(i) / 6
            K.box(&m, V3(x0 + w / 12, 0.7 - drop / 2 - 0.01, 0), V3(w / 6 - 0.002, 0.012, len), i % 2 == 0 ? material : "fabric.linen", bevel: 0.002, rot: simd_quatf(degrees: ang, axis: V3(1, 0, 0)))
        }
        K.box(&m, V3(0, 0.7 - drop - 0.05, d / 2), V3(w, 0.1, 0.012), material, bevel: 0.002)
        K.box(&m, V3(0, 0.7 - drop, d / 2), V3(w, 0.03, 0.03), "metal.aluminum-brushed", bevel: 0.004)
        for sx: Float in [-1, 1] {
            rod(&m, V3(sx * (w / 2 - 0.05), 0.68, -d / 2 + 0.05), V3(sx * (w / 2 - 0.05), 0.7 - drop - 0.02, d / 2 - 0.02), 0.012, "metal.aluminum-brushed", sides: 8)
            rod(&m, V3(sx * (w / 2 - 0.05), 0.55, -d / 2 + 0.05), V3(sx * (w / 2 - 0.05), 0.7 - drop - 0.02, d / 2 - 0.1), 0.01, "metal.aluminum-brushed", sides: 8)
        }
        return K.finish(&m, ao: 0.05)
    }
}
