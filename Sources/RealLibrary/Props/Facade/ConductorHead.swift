import simd
import Foundation

/// Rainwater conductor head (leader head): a riveted copper box with a flared funnel top, scalloped
/// front panel with raised date plate, overflow notch and a tapered downpipe stub with a pipe clip.
/// Wall plane at z = 0, 0.8 m tall including 0.35 m of pipe.
public struct ConductorHead: RealAsset {
    public static let id = "conductor-head"
    public static let summary = "Copper conductor head, 0.8 m: riveted box with flared funnel, scalloped face, date plate, downpipe, clip."
    public static let tags = ["prop", "architecture", "facade", "metal", "ornament"]
    public static let budget = 8_000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 32, elevation: 12, distance: 1.9)

    public var copper: MaterialKey = "metal.copper-patina"
    public var accent: MaterialKey = "metal.copper"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let w: Float = 0.3, d: Float = 0.2, h: Float = 0.34, y0: Float = 0.46
        // Funnel mouth, box body and tapering outlet.
        m.add(Prim.loft([Prim.ring(Shape2D.roundedRect(w + 0.14, d + 0.14, radius: 0.02), y: y0 + h + 0.12, offset: V3(0, 0, d / 2 + 0.0)),
                         Prim.ring(Shape2D.roundedRect(w + 0.02, d + 0.02, radius: 0.012), y: y0 + h, offset: V3(0, 0, d / 2 + 0.0))], capStart: false, capEnd: false, material: copper))
        FA.box(&m, V3(w, h, d), V3(0, y0 + h / 2, d / 2), copper, r: 0.006)
        m.add(Prim.loft([Prim.ring(Shape2D.roundedRect(w - 0.02, d - 0.02, radius: 0.01), y: y0 + 0.0, offset: V3(0, 0, d / 2)),
                         Prim.ring(Shape2D.circle(0.05, segments: Shape2D.roundedRect(w - 0.02, d - 0.02, radius: 0.01).count), y: y0 - 0.1, offset: V3(0, 0, 0.07))], capStart: false, capEnd: false, material: copper))
        // Downpipe, collar and clips.
        FA.rod(&m, V3(0, y0 - 0.1, 0.07), V3(0, 0, 0.07), r: 0.05, copper, sides: 16)
        for y in [0.08, 0.25] as [Float] {
            m.add(Prim.torus(major: 0.054, minor: 0.008, segments: 18, sides: 6, material: accent), Xform(translation: V3(0, y, 0.07)))
            FA.box(&m, V3(0.03, 0.025, 0.02), V3(0, y, 0.015), accent, r: 0.003)
        }
        // Scalloped crest on the front and raised date plate.
        for k in -2...2 {
            m.add(Prim.superellipsoid(V3(0.06, 0.05, 0.012), exponent: 2.4, subdivisions: 5, material: accent), Xform(translation: V3(Float(k) * 0.058, y0 + h - 0.01, d + 0.004)))
        }
        FA.box(&m, V3(0.16, 0.1, 0.008), V3(0, y0 + h * 0.48, d + 0.004), accent, r: 0.003)
        FA.box(&m, V3(0.13, 0.065, 0.004), V3(0, y0 + h * 0.48, d + 0.01), copper, r: 0.002)
        for (x, y) in [(-0.13, 0.13), (0.13, 0.13), (-0.13, -0.13), (0.13, -0.13), (0, 0.145), (0, -0.145)] as [(Float, Float)] {
            rivet(&m, at: V3(x, y0 + h / 2 + y, d), normal: FA.Z, radius: 0.007, material: accent)
        }
        // Overflow notch dark.
        FA.box(&m, V3(0.05, 0.03, 0.03), V3(0, y0 + h + 0.06, d + 0.05), "metal.rust", r: 0.003)
        groundAO(&m, height: 0.15, floor: 0.8)
        return LODModel(FC.place(m))
    }
}
