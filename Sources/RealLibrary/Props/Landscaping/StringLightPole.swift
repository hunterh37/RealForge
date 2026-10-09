import simd
import Foundation

/// Pole 2.5 m, strands reach 0.95 m from the pole at 2.1 m.
public struct StringLightPole: RealAsset {
    public static let id = "string-light-pole"
    public static let summary = "Bistro light pole, 2.5 m: black pole on a concrete-filled base with four sagging strands of warm bulbs."
    public static let tags = ["prop", "landscaping", "garden", "outdoor", "light", "metal"]
    public static let budget = 7000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 35, elevation: 18)
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let black = "metal.painted:1C1C1E"
        m.add(Prim.cylinder(radius: 0.17, height: 0.12, bevel: 0.008, segments: 28, material: "concrete.rough"))
        m.add(Prim.cylinder(radius: 0.018, height: 2.48, bevel: 0.003, segments: 12, material: black), Xform(translation: V3(0, 0.12, 0)))
        m.add(Prim.superellipsoid(V3(0.05, 0.05, 0.05), exponent: 2, subdivisions: 4, material: black), Xform(translation: V3(0, 2.62, 0)))
        for k in 0..<4 {
            let a = Float(k) * .pi / 2 + 0.3, dx = cos(a), dz = sin(a)
            var wire: [V3] = []
            for i in 0...12 {
                let t = Float(i) / 12
                wire.append(V3(dx * 0.95 * t, 2.55 - 0.45 * t - 0.2 * 4 * t * (1 - t), dz * 0.95 * t))
            }
            K.rod(&m, wire, r: 0.003, black, sides: 5)
            for i in stride(from: 2, to: 12, by: 2) {
                m.add(Prim.superellipsoid(V3(0.045, 0.06, 0.045), exponent: 2, subdivisions: 4, material: "emissive.warm"),
                      Xform(translation: wire[i] - V3(0, 0.04, 0)))
            }
        }
        return K.finish(&m)
    }
}
