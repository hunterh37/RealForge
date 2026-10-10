import simd
import Foundation

/// Round porthole window: 0.6 m brushed stainless ring, twelve bolts, inner gasket and a tinted pane
/// with a diagonal sheen bar. Wall plane at z = 0.
public struct PortholeWindow: RealAsset {
    public static let id = "porthole-window"
    public static let summary = "Round porthole window, 0.6 m: stainless ring with 12 bolts, rubber gasket, tinted pane."
    public static let tags = ["prop", "architecture", "facade", "window", "metal", "glass"]
    public static let budget = 8500
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 25, elevation: 8, distance: 1.4)

    public var diameter: Float = 0.6
    public var ring: MaterialKey = "metal.stainless"
    public var glass: MaterialKey = "glass.tinted"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let R = diameter / 2, cy = R
        FA.cylZ(&m, r: R, h: 0.04, at: V3(0, cy, 0), ring, bevel: 0.006, segments: 40)
        m.add(Prim.torus(major: R * 0.8, minor: 0.03, segments: 40, sides: 10, material: ring),
              Xform(translation: V3(0, cy, 0.05), rotation: FA.q(90, FA.X)))
        m.add(Prim.torus(major: R * 0.62, minor: 0.016, segments: 36, sides: 8, material: "rubber"),
              Xform(translation: V3(0, cy, 0.045), rotation: FA.q(90, FA.X)))
        FA.cylZ(&m, r: R * 0.62, h: 0.012, at: V3(0, cy, 0.03), glass, bevel: 0.001, segments: 36)
        for k in 0..<12 {
            let a = Float(k) / 12 * 2 * .pi + 0.13
            hexBolt(&m, at: V3(cos(a) * R * 0.88, cy + sin(a) * R * 0.88, 0.04), normal: FA.Z, size: 0.016, material: "metal.steel")
        }
        FA.box(&m, V3(0.025, R * 0.7, 0.003), V3(-R * 0.18, cy + R * 0.05, 0.043), "glass.clear", r: 0.001, rot: FA.q(35, FA.Z))
        groundAO(&m, height: 0.08, floor: 0.9)
        return LODModel(FC.place(m))
    }
}
