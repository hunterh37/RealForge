import simd
import Foundation

/// Ox-eye oculus window: 0.9 m round opening ringed by a limestone torus, four cardinal keystones,
/// iron glazing bars in a wheel pattern and a leaded tinted pane. Wall plane at z = 0.
public struct OculusWindow: RealAsset {
    public static let id = "oculus-window"
    public static let summary = "Round oculus window, 0.9 m: stone ring with four keystones, iron wheel glazing bars."
    public static let tags = ["prop", "architecture", "facade", "window", "stone", "glass"]
    public static let budget = 9_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 25, elevation: 8, distance: 2.0)

    public var diameter: Float = 0.9
    public var stone: MaterialKey = "stone.limestone"
    public var iron: MaterialKey = "metal.wrought-iron"
    public var glass: MaterialKey = "glass.tinted"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let R = diameter / 2, cy = R + 0.12
        FA.cylZ(&m, r: R, h: 0.012, at: V3(0, cy, 0.025), glass, bevel: 0.001, segments: 40)
        m.add(Prim.torus(major: R + 0.045, minor: 0.05, segments: 40, sides: 12, material: stone),
              Xform(translation: V3(0, cy, 0.05), rotation: FA.q(90, FA.X)))
        m.add(Prim.torus(major: R + 0.12, minor: 0.018, segments: 40, sides: 8, material: stone),
              Xform(translation: V3(0, cy, 0.03), rotation: FA.q(90, FA.X)))
        for k in 0..<4 {
            let a = Float(k) * .pi / 2
            let c = V3(cos(a) * (R + 0.045), cy + sin(a) * (R + 0.045), 0.06)
            FA.box(&m, V3(0.15, 0.17, 0.09), c, stone, r: 0.006, rot: FA.q(Float(k) * 90, FA.Z))
        }
        // Wheel glazing: eight spokes, hub ring and mid ring.
        for k in 0..<8 {
            let a = Float(k) * .pi / 4
            FA.rod(&m, V3(0, cy, 0.04), V3(cos(a) * R, cy + sin(a) * R, 0.04), r: 0.007, iron, sides: 6)
        }
        m.add(Prim.torus(major: 0.07, minor: 0.012, segments: 18, sides: 6, material: iron), Xform(translation: V3(0, cy, 0.04), rotation: FA.q(90, FA.X)))
        m.add(Prim.torus(major: R * 0.55, minor: 0.006, segments: 28, sides: 5, material: iron), Xform(translation: V3(0, cy, 0.04), rotation: FA.q(90, FA.X)))
        FA.box(&m, V3(diameter * 0.5, 0.05, 0.1), V3(0, 0.025, 0.05), stone, r: 0.004)
        groundAO(&m, height: 0.1, floor: 0.88)
        return LODModel(FA.centerZ(m))
    }
}
