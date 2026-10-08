import simd
import Foundation

/// Roman Doric column: square plinth, torus base, 20-flute shaft with entasis (flutes meeting at sharp
/// arrises), astragal and necking, echinus and square abacus. Centered on X/Z, base at y = 0.
public struct DoricColumn: RealAsset {
    public static let id = "doric-column"
    public static let summary = "Roman Doric column, 3.6 m: plinth, torus base, 20-flute shaft with entasis, astragal, echinus and abacus."
    public static let tags = ["structure", "architecture", "facade", "trim", "stone"]
    public static let budget = 16_000
    public static let author = "hunter"
    public static let preview = PreviewHint(azimuth: 25, elevation: 6, distance: 1.0)

    /// Overall height (m).
    public var height: Float = 3.6
    /// Lower shaft diameter (m).
    public var diameter: Float = 0.5
    /// Number of flutes (0 = plain shaft).
    public var flutes = 20
    /// Upper shaft radius as a fraction of the lower.
    public var taper: Float = 0.84
    /// Rain streak and soot strength.
    public var weathering: Float = 0.45
    public var material: MaterialKey = "stone.limestone"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let r = diameter / 2, H = height
        let ph = r * 0.5
        ColumnKit.plinth(&m, side: diameter * 1.36, h: ph, material: material)
        // Torus base.
        var b = ArchProfile(V2(0, ph))
        b.to(V2(r * 1.16, ph)); b.torus(r * 0.16); b.step(-r * 0.1); b.fillet(r * 0.04)
        b.cavetto(r * 0.06, -r * 0.06)
        let by = b.end.y
        b.to(V2(0, by))
        m.add(ArchTrimKit.lathe(b, segments: 48, material: material))
        // Capital heights: abacus, echinus, necking, astragal.
        let abH = r * 0.32, echH = r * 0.28, neckH = r * 0.5
        let neckTop = H - abH - echH
        let shaftTop = neckTop - neckH - r * 0.08
        let r1 = r * taper
        m.add(ColumnKit.shaft(y0: by - 0.005, y1: shaftTop + 0.005, r0: r, r1: r1,
                              fluting: flutes > 0 ? .arris(flutes) : .none, depth: r * 0.045, material: material))
        var c = ArchProfile(V2(0, shaftTop))
        c.to(V2(r1, shaftTop)); c.bead(r * 0.04); c.step(-r * 0.02); c.fillet(neckH)
        c.step(r * 0.06); c.fillet(r * 0.025)
        c.ovolo(echH - r * 0.025, r * 0.22)
        c.to(V2(0, c.end.y))
        m.add(ArchTrimKit.lathe(c, segments: 48, material: material))
        m.add(Prim.roundedBox(V3(diameter * 1.3, abH, diameter * 1.3), radius: 0.008, bevelSegments: 2, material: material),
              Xform(translation: V3(0, H - abH / 2, 0)))
        ArchTrimKit.weather(&m, seed: seed, amount: weathering)
        groundAO(&m, height: 0.4, floor: 0.6)
        return LODModel(ArchTrimKit.ground(m))
    }
}
