import simd
import Foundation

/// Ionic column: plinth, attic base, 24 filleted flutes with entasis, astragal, echinus, paired volute
/// scrolls joined by a cushion (pulvinus) on each side, and a thin molded abacus. Volutes face +Z/-Z.
/// Centered on X/Z, base at y = 0.
public struct IonicColumn: RealAsset {
    public static let id = "ionic-column"
    public static let summary = "Ionic column, 4 m: attic base, 24 filleted flutes, astragal, echinus and paired volute scrolls under a thin abacus."
    public static let tags = ["structure", "architecture", "facade", "trim", "stone", "ornament"]
    public static let budget = 24_000
    public static let author = "hunter"
    public static let preview = PreviewHint(azimuth: 20, elevation: 6, distance: 1.0)

    /// Overall height (m).
    public var height: Float = 4.0
    /// Lower shaft diameter (m).
    public var diameter: Float = 0.44
    /// Number of flutes (0 = plain shaft).
    public var flutes = 24
    /// Rain streak and soot strength.
    public var weathering: Float = 0.3
    public var material: MaterialKey = "stone.marble-honed"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let r = diameter / 2, H = height
        let ph = r * 0.45
        ColumnKit.plinth(&m, side: diameter * 1.4, h: ph, material: material)
        let by = ColumnKit.atticBase(&m, y0: ph, r: r, material: material)
        let abH = r * 0.16, volR = r * 0.42
        let capH = r * 0.75
        let shaftTop = H - capH
        let r1 = r * 0.85
        m.add(ColumnKit.shaft(y0: by - 0.004, y1: shaftTop + 0.004, r0: r, r1: r1,
                              fluting: flutes > 0 ? .fillet(flutes) : .none, depth: r * 0.06, material: material))
        // Astragal and echinus.
        var c = ArchProfile(V2(0, shaftTop))
        c.to(V2(r1, shaftTop)); c.bead(r * 0.045); c.step(-r * 0.01); c.fillet(r * 0.04)
        c.ovolo(r * 0.16, r * 0.17)
        let echTop = c.end.y
        c.to(V2(0, echTop))
        m.add(ArchTrimKit.lathe(c, segments: 48, material: material))
        // Volute band: canalis across the front and back, cushions along Z at each side, spirals on both faces.
        let vy = H - abH - volR * 0.95
        let span = r1 + volR * 0.55
        let bandH = volR * 0.9, bandZ = r1 * 1.05
        m.add(Prim.roundedBox(V3(2 * span, bandH, 2 * bandZ), radius: 0.01, bevelSegments: 2, material: material),
              Xform(translation: V3(0, H - abH - bandH / 2, 0)))
        let cushion = Prim.cylinder(radius: volR, height: 2 * bandZ, bevel: 0.006, segments: 28, material: material)
        let vol = ArchTrimKit.volute(radius: volR * 0.96, turns: 2.75, wire: r * 0.025, material: material)
        for s in [Float(-1), 1] {
            m.add(cushion, Xform(translation: V3(s * span, vy, -bandZ), rotation: simd_quatf(angle: .pi / 2, axis: V3(1, 0, 0))))
            m.add(vol, Xform(translation: V3(s * span, vy, bandZ + 0.001), rotation: s < 0 ? .identity : simd_quatf(angle: .pi, axis: V3(0, 1, 0)) * simd_quatf(angle: .pi, axis: V3(0, 1, 0))))
            m.add(vol, Xform(translation: V3(s * span, vy, -bandZ - 0.001), rotation: simd_quatf(angle: .pi, axis: V3(0, 1, 0))))
            // Cushion binding (balteus) at mid-length.
            m.add(Prim.torus(major: volR * 0.9, minor: r * 0.02, segments: 24, sides: 6, material: material),
                  Xform(translation: V3(s * span, vy, 0), rotation: simd_quatf(angle: .pi / 2, axis: V3(1, 0, 0))))
        }
        // Abacus with an ovolo edge.
        let side = 2 * (span + volR * 0.3)
        m.add(Prim.roundedBox(V3(side, abH, side * 0.9), radius: abH * 0.35, bevelSegments: 3, material: material),
              Xform(translation: V3(0, H - abH / 2, 0)))
        ArchTrimKit.weather(&m, seed: seed, amount: weathering)
        groundAO(&m, height: 0.4, floor: 0.6)
        return LODModel(ArchTrimKit.ground(m))
    }
}
