import simd
import Foundation

/// Festoon string lights: three catenary strands across a 3 m wall span between steel eye hooks,
/// fourteen warm bulbs per strand on black sockets with drip loops and a plug tail. Wall plane at z = 0.
public struct FestoonStringLights: RealAsset {
    public static let id = "festoon-string-lights"
    public static let summary = "Festoon string lights, 3 m span: three drooping strands on eye hooks, 14 warm bulbs each, sockets, plug tail."
    public static let tags = ["prop", "architecture", "facade", "light", "electrical"]
    public static let budget = 13500
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 35, elevation: 8, distance: 4.0)

    public var span: Float = 3.0
    public var bulbsPerStrand: Int = 14
    public var topHeight: Float = 0.9
    public var wire: MaterialKey = "plastic.black"
    public var bulb: MaterialKey = "emissive.warm"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let S = span, strands = 3, n = bulbsPerStrand
        let hooks: [Float] = [-S / 2, -S / 6, S / 6, S / 2]
        for x in hooks {
            FA.cylZ(&m, r: 0.012, h: 0.006, at: V3(x, topHeight, 0), "metal.steel", bevel: 0.001, segments: 10)
            m.add(Prim.torus(major: 0.012, minor: 0.0035, segments: 12, sides: 6, material: "metal.steel"), Xform(translation: V3(x, topHeight, 0.05), rotation: FA.q(90, FA.Z)))
            FA.rod(&m, V3(x, topHeight, 0.0), V3(x, topHeight, 0.04), r: 0.004, "metal.steel", sides: 6)
        }
        for s in 0..<strands {
            let x0 = hooks[s], x1 = hooks[s + 1], sag: Float = 0.2 + rng.float(0...0.05)
            var pts: [V3] = []
            let steps = 24
            for k in 0...steps {
                let t = Float(k) / Float(steps)
                pts.append(V3(x0 + (x1 - x0) * t, topHeight - sin(t * .pi) * sag, 0.05 + sin(t * .pi) * 0.05))
            }
            m.add(Prim.tube(pts, radii: Array(repeating: 0.0028, count: pts.count), sides: 6, seamTile: 0.1, material: wire))
            for b in 0..<n {
                let t = (Float(b) + 0.5) / Float(n), p = pts[min(steps, Int(t * Float(steps)))]
                let sock = p + V3(0, -0.012, 0)
                m.add(Prim.lathe([V2(0, 0), V2(0.012, 0), V2(0.014, 0.016), V2(0.01, 0.03), V2(0, 0.03)], segments: 10, material: wire),
                      Xform(translation: sock + V3(0, -0.03, 0)))
                m.add(Prim.superellipsoid(V3(0.04, 0.054, 0.04), exponent: 2, subdivisions: 3, material: bulb), Xform(translation: sock + V3(0, -0.06, 0)))
                m.add(Prim.lathe([V2(0.004, 0), V2(0.007, 0.01), V2(0.004, 0.022)], segments: 6, material: "metal.brass"), Xform(translation: sock + V3(0, -0.032, 0)))
            }
        }
        // Plug tail down the wall from the last hook.
        FA.path(&m, [V3(S / 2, topHeight, 0.04), V3(S / 2 - 0.03, topHeight - 0.4, 0.03), V3(S / 2 - 0.05, topHeight - 0.8, 0.02)], r: 0.003, wire, sides: 6)
        FA.box(&m, V3(0.04, 0.06, 0.03), V3(S / 2 - 0.05, topHeight - 0.84, 0.02), "plastic.black", r: 0.004)
        groundAO(&m, height: 0.05, floor: 0.95)
        return LODModel(FC.place(m))
    }
}
