import simd
import Foundation

/// Weathervane: a 1.1 m copper rooster on an arrow shaft above N-E-S-W cardinal letters on crossed
/// iron arms, with a glass ball and a stainless pivot. The rooster is an extruded silhouette.
public struct Weathervane: RealAsset {
    public static let id = "weathervane"
    public static let summary = "Weathervane, 1.1 m: copper rooster and arrow on a spindle with N-E-S-W arms and glass ball."
    public static let tags = ["prop", "architecture", "facade", "roof", "metal"]
    public static let budget = 7_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 30, elevation: 8, distance: 2.6)

    public var armSpan: Float = 0.7
    public var copper: MaterialKey = "metal.copper"
    public var aged: MaterialKey = "metal.copper-patina"
    public var iron: MaterialKey = "metal.wrought-iron"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        FA.rod(&m, V3(0, 0, 0), V3(0, 0.78, 0), r: 0.012, iron, sides: 10)
        FA.cylZ(&m, r: 0.04, h: 0.03, at: V3(0, 0.0, 0), iron, segments: 16)
        // Cardinal arms with letters (small boxes) and ball tips.
        let cy: Float = 0.34
        for k in 0..<4 {
            let a = Float(k) * .pi / 2
            let d = V3(cos(a), 0, sin(a))
            FA.rod(&m, V3(0, cy, 0), d * (armSpan / 2) + V3(0, cy, 0), r: 0.007, iron, sides: 8)
            FA.ball(&m, r: 0.016, at: d * (armSpan / 2) + V3(0, cy, 0), iron)
            let lc = d * (armSpan / 2 + 0.06) + V3(0, cy, 0)
            FA.box(&m, V3(0.04, 0.05, 0.008), lc, aged, r: 0.001, rot: FA.q(-Float(k) * 90, FA.Y))
        }
        m.add(Prim.torus(major: 0.15, minor: 0.005, segments: 28, sides: 5, material: iron), Xform(translation: V3(0, cy - 0.05, 0)))
        // Rooster silhouette (side view in the XY plane), extruded 8 mm, on the vane axis.
        let rooster: [V2] = [V2(-0.22, 0.52), V2(-0.18, 0.5), V2(-0.14, 0.44), V2(-0.08, 0.4), V2(-0.02, 0.4), V2(0.04, 0.44), V2(0.1, 0.5),
                             V2(0.13, 0.56), V2(0.17, 0.64), V2(0.15, 0.7), V2(0.18, 0.72), V2(0.2, 0.68), V2(0.22, 0.66), V2(0.2, 0.6),
                             V2(0.17, 0.52), V2(0.1, 0.44), V2(0.04, 0.38), V2(-0.02, 0.36), V2(-0.1, 0.36), V2(-0.16, 0.4), V2(-0.22, 0.46)]
        let body = Shape2D.rounded(Shape2D.deduped(rooster), radius: 0.01)
        m.add(Prim.extrude(body, depth: 0.008, bevel: 0.002, bevelSegments: 1, material: copper), Xform(translation: V3(0, 0.14, 0)))
        // Arrow tail counterweight.
        let tail = [V2(-0.3, 0.5), V2(-0.2, 0.55), V2(-0.2, 0.5), V2(-0.2, 0.45)]
        m.add(Prim.extrude(tail, depth: 0.006, bevel: 0.001, bevelSegments: 1, material: aged), Xform(translation: V3(0, 0.12, 0)))
        FA.ball(&m, r: 0.045, at: V3(0, 0.82, 0), "glass.frosted")
        FA.rod(&m, V3(0, 0.78, 0), V3(0, 0.86, 0), r: 0.006, "metal.stainless", sides: 6)
        groundAO(&m, height: 0.08, floor: 0.9)
        return LODModel(FC.place(m))
    }
}
