import simd
import Foundation

/// Pedestal 0.72 m, dial 0.32 m diameter.
public struct Sundial: RealAsset {
    public static let id = "sundial"
    public static let summary = "Garden sundial, 0.83 m: cast stone baluster pedestal with a brass dial plate, hour marks and a triangular gnomon."
    public static let tags = ["prop", "landscaping", "garden", "outdoor", "decor", "stone"]
    public static let budget = 3500
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 35, elevation: 18)
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        m.add(turned([(0, 0), (0.18, 0), (0.18, 0.06), (0.13, 0.1), (0.1, 0.14), (0.08, 0.3), (0.09, 0.45), (0.07, 0.6), (0.11, 0.68), (0.17, 0.72), (0, 0.72)],
                     segments: 36, material: "stone.cast-stone"))
        m.add(Prim.cylinder(radius: 0.16, height: 0.012, bevel: 0.003, segments: 36, material: "metal.brass-aged"), Xform(translation: V3(0, 0.72, 0)))
        for k in 0..<12 {
            let a = Float(k) * .pi / 6
            K.box(&m, V3(cos(a) * 0.125, 0.734, sin(a) * 0.125), V3(0.006, 0.003, 0.03), "metal.brass-aged", bevel: 0.001,
                  rot: simd_quatf(angle: -a, axis: .up))
        }
        m.add(Prim.extrude([V2(0, 0), V2(0.14, 0), V2(0.14, 0.1)], depth: 0.004, bevel: 0.001, material: "metal.brass-aged"),
              Xform(translation: V3(-0.07, 0.732, 0), rotation: K.yaw(0)))
        return K.finish(&m)
    }
}
