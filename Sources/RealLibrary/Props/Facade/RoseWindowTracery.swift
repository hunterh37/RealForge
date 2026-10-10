import simd
import Foundation

/// Gothic rose window: 1.7 m cast-stone frame, twelve radial mullions, twelve petal lights in alternating
/// stained glass, an inner trefoil ring and a central boss. Wall plane at z = 0.
public struct RoseWindowTracery: RealAsset {
    public static let id = "rose-window-tracery"
    public static let summary = "Gothic rose window, 1.7 m: cast-stone frame, 12 radial mullions, stained-glass petal lights, central boss."
    public static let tags = ["prop", "architecture", "facade", "window", "ornament", "stone", "glass"]
    public static let budget = 10000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 20, elevation: 6, distance: 3.2, studio: true)

    public var diameter: Float = 1.7
    public var petals: Int = 12
    public var stone: MaterialKey = "stone.cast-stone"
    public var glassA: MaterialKey = "glass.tinted:B3312F"
    public var glassB: MaterialKey = "glass.tinted:2D5BA6"
    public var backing: MaterialKey = "glass.tinted:1E2A44"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let R = diameter / 2, cy = R + 0.02, n = max(6, petals)
        let ring = { (r: Float, minor: Float, z: Float) in
            m.add(Prim.torus(major: r, minor: minor, segments: 36, sides: 6, material: stone),
                  Xform(translation: V3(0, cy, z), rotation: FA.q(90, FA.X)))
        }
        ring(R - 0.05, 0.05, 0.06)
        FA.cylZ(&m, r: R - 0.08, h: 0.02, at: V3(0, cy, 0.02), backing, bevel: 0.001, segments: 32)
        FA.cylZ(&m, r: R + 0.01, h: 0.05, at: V3(0, cy, 0), stone, bevel: 0.004, segments: 32)
        FA.cylZ(&m, r: R - 0.1, h: 0.08, at: V3(0, cy, 0.0), "metal.cast-iron", bevel: 0.001, segments: 32)
        for k in 0..<n {
            let a = Float(k) / Float(n) * 2 * .pi
            let d = V3(cos(a), sin(a), 0)
            // Radial mullion from the boss to the frame.
            FA.box(&m, V3(R - 0.2, 0.035, 0.05), V3(d.x, d.y, 0) * ((R - 0.2) / 2 + 0.16) + V3(0, cy, 0.06), stone, r: 0.004,
                   rot: FA.q(a * 180 / .pi, FA.Z))
            // Petal light with a stone surround.
            let c = V3(d.x * R * 0.62, cy + d.y * R * 0.62, 0.04)
            FA.cylZ(&m, r: R * 0.17, h: 0.03, at: c, k % 2 == 0 ? glassA : glassB, bevel: 0.001, segments: 14)
            m.add(Prim.torus(major: R * 0.17, minor: 0.014, segments: 14, sides: 4, material: stone),
                  Xform(translation: c + V3(0, 0, 0.035), rotation: FA.q(90, FA.X)))
            // Cusp between petals on the inner ring.
            let b = a + .pi / Float(n)
            FC.bead(&m, r: 0.022, at: V3(cos(b) * R * 0.36, cy + sin(b) * R * 0.36, 0.08), stone)
        }
        ring(R * 0.33, 0.022, 0.075)
        ring(R * 0.5, 0.016, 0.07)
        FA.cylZ(&m, r: 0.1, h: 0.07, at: V3(0, cy, 0.04), stone, bevel: 0.006, segments: 24)
        FA.cylZ(&m, r: 0.06, h: 0.03, at: V3(0, cy, 0.105), glassA, bevel: 0.002, segments: 14)
        groundAO(&m, height: 0.1, floor: 0.9)
        return LODModel(FC.place(m))
    }
}
