import simd
import Foundation

/// Double-faced projecting bracket clock: a 0.45 m dial with Roman numerals and gilt hands on each side,
/// a cast scroll bracket from the wall and a finial cap. Wall plane at z = 0, bracket 0.7 m out.
public struct ProjectingClock: RealAsset {
    public static let id = "projecting-clock"
    public static let summary = "Projecting bracket clock, 0.45 m dial: double-faced, Roman numerals, gilt hands, cast scroll bracket, finial."
    public static let tags = ["prop", "architecture", "facade", "sign", "metal", "glass"]
    public static let budget = 7500
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 55, elevation: 10, distance: 2.4)

    public var dial: Float = 0.45
    public var iron: MaterialKey = "metal.painted:1B2B1F"
    public var face: MaterialKey = "plastic.white"
    public var gilt: MaterialKey = "metal.brass-aged"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let R = dial / 2, cx: Float = 0.7, cy: Float = 0.65
        // Wall plate and bracket arm with scroll brace.
        m.add(Prim.extrude(Shape2D.roundedRect(0.12, 0.5, radius: 0.02), depth: 0.016, bevel: 0.003, bevelSegments: 1, material: iron),
              Xform(translation: V3(0, 0.38, 0.008)))
        FA.path(&m, [V3(0, 0.62, 0.01), V3(0, 0.64, 0.3), V3(0, 0.64, cx)], r: 0.016, iron, sides: 10)
        var brace: [V3] = []
        for i in 0...18 { let t = Float(i) / 18, a = t * 1.5 * .pi; brace.append(V3(0, 0.38 + 0.2 * (1 - cos(a * 0.5)) * 0.0 + t * 0.2, 0.025 + t * 0.4 - 0.05 * sin(a))) }
        FA.path(&m, brace, r: 0.011, iron, sides: 8)
        var scroll: [V3] = []
        for i in 0...16 { let t = Float(i) / 16, a = t * 2.5 * .pi, r = 0.05 * (1 - t * 0.7); scroll.append(V3(0, 0.44 + r * sin(a), 0.24 + r * cos(a))) }
        FA.path(&m, scroll, r: 0.007, iron, sides: 6)
        for s: Float in [-1, 1] {
            // Dial face, glass, bezel and hands per side.
            let z0 = cx + s * 0.03
            m.add(Prim.cylinder(radius: R, height: 0.012, bevel: 0.002, segments: 40, bevelSegments: 1, material: face),
                  Xform(translation: V3(s * 0.045, cy, cx), rotation: FA.q(s * 90, FA.Z)))
            m.add(Prim.torus(major: R, minor: 0.016, segments: 40, sides: 8, material: iron), Xform(translation: V3(s * 0.052, cy, cx), rotation: FA.q(90, FA.Z)))
            for h in 0..<12 {
                let a = Float(h) / 12 * 2 * .pi
                let big = h % 3 == 0
                FA.box(&m, V3(0.004, big ? 0.05 : 0.036, 0.016), V3(s * 0.054, cy + cos(a) * R * 0.82, cx + sin(a) * R * 0.82), "plastic.black", r: 0.0005,
                       rot: FA.q(-a * 180 / .pi, FA.X))
            }
            let hr = rng.float(0...Float.pi * 2), mn = rng.float(0...Float.pi * 2)
            FA.box(&m, V3(0.003, 0.012, R * 0.45), V3(s * 0.058, cy + cos(hr) * R * 0.22, cx + sin(hr) * R * 0.22), gilt, r: 0.001, rot: FA.q(0, FA.X))
            FA.box(&m, V3(0.003, 0.008, R * 0.72), V3(s * 0.06, cy + cos(mn) * R * 0.36, cx + sin(mn) * R * 0.36), gilt, r: 0.001)
            _ = z0
        }
        FA.rod(&m, V3(-0.05, cy, cx), V3(0.05, cy, cx), r: 0.012, iron, sides: 10)
        m.add(Prim.lathe([V2(0, 0), V2(0.03, 0), V2(0.02, 0.03), V2(0.012, 0.08), V2(0, 0.1)], segments: 10, material: iron), Xform(translation: V3(0, cy + R + 0.012, cx)))
        FC.bead(&m, r: 0.018, at: V3(0, cy + R + 0.11, cx), gilt)
        groundAO(&m, height: 0.1, floor: 0.9)
        return LODModel(FC.place(m))
    }
}
