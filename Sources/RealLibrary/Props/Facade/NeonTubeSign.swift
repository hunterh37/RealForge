import simd
import Foundation

/// Neon tube sign: a 1.0 x 0.5 m black raceway-backed script word "OPEN" bent from glowing tube in an
/// oval border, on four glass standoffs, with transformer box, electrode boots and a hanging chain.
/// Wall plane at z = 0.
public struct NeonTubeSign: RealAsset {
    public static let id = "neon-tube-sign"
    public static let summary = "Neon tube sign, 1.0 x 0.5 m: script OPEN and oval border in glowing tube on a black backer with standoffs."
    public static let tags = ["prop", "architecture", "facade", "sign", "light", "glass"]
    public static let budget = 3500
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 20, elevation: 6, distance: 2.0, studio: true)

    public var tube: MaterialKey = "emissive.signal-red"
    public var border: MaterialKey = "emissive.signal-white"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let W: Float = 1.0, H: Float = 0.5, z: Float = 0.07
        m.add(Prim.extrude(Shape2D.roundedRect(W, H, radius: 0.08), depth: 0.01, bevel: 0.002, bevelSegments: 1, material: "plastic.black"),
              Xform(translation: V3(0, H / 2, 0.065)))
        // Oval border tube.
        let oval: [V3] = (0...48).map { i in let a = Float(i) / 48 * 2 * .pi; return V3(cos(a) * (W / 2 - 0.05), H / 2 + sin(a) * (H / 2 - 0.05), z) }
        m.add(Prim.tube(oval, radii: Array(repeating: 0.0085, count: oval.count), sides: 8, seamTile: 0.1, material: border, capEnd: true))
        // Script letters as hand-bent paths: O, P, E, N.
        let o: [V3] = (0...20).map { i in let a = Float(i) / 20 * 2 * .pi; return V3(-0.32 + cos(a) * 0.07, 0.25 + sin(a) * 0.1, z) }
        let pLoop: [V3] = [V3(-0.18, 0.15, z), V3(-0.18, 0.35, z)] + (0...10).map { i in let a = Float.pi / 2 - Float(i) / 10 * .pi; return V3(-0.18 + cos(a) * 0.06, 0.295 + sin(a) * 0.055, z) }
        let e: [V3] = [V3(0.0, 0.25, z), V3(-0.04, 0.25, z), V3(-0.03, 0.32, z), V3(-0.0, 0.35, z), V3(0.04, 0.31, z), V3(0.0, 0.25, z), V3(0.0, 0.2, z), V3(0.04, 0.15, z)]
        let nn: [V3] = [V3(0.12, 0.15, z), V3(0.12, 0.35, z), V3(0.2, 0.15, z), V3(0.28, 0.35, z), V3(0.28, 0.15, z)]
        for path in [o, pLoop, e, nn] {
            let pp = path.count >= 4 ? path : path
            m.add(Prim.tube(pp, radii: Array(repeating: 0.0095, count: pp.count), sides: 8, seamTile: 0.1, material: tube, capEnd: true))
        }
        // Underline swash.
        m.add(Prim.tube([V3(-0.4, 0.1, z), V3(-0.1, 0.085, z), V3(0.2, 0.095, z), V3(0.38, 0.115, z)], radii: [0.0085, 0.0085, 0.0085, 0.0085], sides: 8, seamTile: 0.1, material: border))
        // Standoffs, electrode boots and transformer.
        for p in [V3(-0.42, 0.07, 0), V3(0.42, 0.07, 0), V3(-0.42, 0.43, 0), V3(0.42, 0.43, 0)] {
            FA.rod(&m, p, p + V3(0, 0, 0.065), r: 0.007, "glass.clear", sides: 8)
            FA.cylZ(&m, r: 0.013, h: 0.004, at: p + V3(0, 0, 0.065), "metal.stainless", bevel: 0.001, segments: 10)
        }
        for p in [V3(-0.4, 0.1, 0.065), V3(0.38, 0.115, 0.065)] { FA.cylZ(&m, r: 0.016, h: 0.022, at: p, "plastic.black", bevel: 0.003, segments: 10) }
        FA.box(&m, V3(0.16, 0.09, 0.07), V3(0.34, -0.0, 0.035), "metal.transformer-gray", r: 0.005)
        FA.path(&m, [V3(0.34, 0.045, 0.04), V3(0.38, 0.1, 0.06), V3(0.38, 0.115, 0.07)], r: 0.003, "plastic.black", sides: 6)
        groundAO(&m, height: 0.1, floor: 0.9)
        return LODModel(FC.place(m))
    }
}
