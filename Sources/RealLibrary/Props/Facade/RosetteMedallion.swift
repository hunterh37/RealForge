import simd
import Foundation

/// Carved rosette medallion: a 0.5 m cast-stone disc with a beaded rim, two rings of sixteen petals,
/// a fluted dish and a domed center boss. Wall plane at z = 0.
public struct RosetteMedallion: RealAsset {
    public static let id = "rosette-medallion"
    public static let summary = "Rosette medallion, 0.5 m: stone disc with beaded rim, two rings of 16 petals, fluted dish and domed boss."
    public static let tags = ["prop", "architecture", "facade", "trim", "ornament", "stone"]
    public static let budget = 9500
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 20, elevation: 6, distance: 1.5)

    public var diameter: Float = 0.5
    public var petals: Int = 16
    public var stone: MaterialKey = "stone.cast-stone"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let R = diameter / 2, cy = R, n = max(8, petals)
        FA.cylZ(&m, r: R, h: 0.03, at: V3(0, cy, 0), stone, bevel: 0.006, segments: 32)
        m.add(Prim.torus(major: R * 0.92, minor: 0.012, segments: 32, sides: 4, material: stone), Xform(translation: V3(0, cy, 0.034), rotation: FA.q(90, FA.X)))
        for k in 0..<(n * 2) {
            let a = Float(k) / Float(n * 2) * 2 * .pi
            FC.bead(&m, r: 0.011, at: V3(cos(a) * R * 0.83, cy + sin(a) * R * 0.83, 0.04), stone)
        }
        for (ring, scale, z, w) in [(0, Float(0.62), Float(0.045), Float(0.07)), (1, Float(0.4), Float(0.058), Float(0.055))] {
            for k in 0..<n {
                let a = (Float(k) + Float(ring) * 0.5) / Float(n) * 2 * .pi
                m.add(Prim.superellipsoid(V3(w, R * 0.42 * (ring == 0 ? 1 : 0.7), 0.026), exponent: 2.2, subdivisions: 3, material: stone),
                      Xform(translation: V3(cos(a) * R * scale, cy + sin(a) * R * scale, z), rotation: FA.q(a * 180 / .pi - 90, FA.Z)))
            }
        }
        m.add(Prim.lathe([V2(0, 0), V2(R * 0.22, 0), V2(R * 0.2, 0.02), V2(R * 0.12, 0.05), V2(0.02, 0.058), V2(0, 0.06)], segments: 24, material: stone),
              Xform(translation: V3(0, cy, 0.07), rotation: FA.q(90, FA.X)))
        FC.bead(&m, r: 0.03, at: V3(0, cy, 0.12), "metal.brass-aged")
        groundAO(&m, height: 0.08, floor: 0.9)
        return LODModel(FC.place(m))
    }
}
