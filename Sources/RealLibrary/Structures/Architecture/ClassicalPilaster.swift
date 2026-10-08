import simd
import Foundation

/// Classical (Roman Doric) pilaster: plinth and attic-style base moldings returned to the wall, a shallow
/// shaft with sunk flutes, an astragal, necking, echinus and abacus capital, all returned at the sides.
/// Back on the wall plane; base at y = 0, centered on X.
public struct ClassicalPilaster: RealAsset {
    public static let id = "classical-pilaster"
    public static let summary = "Classical pilaster, 3 m: plinth, attic base, fluted shaft, astragal, echinus capital and abacus projecting from the wall."
    public static let tags = ["structure", "architecture", "facade", "trim", "stone"]
    public static let budget = 9_000
    public static let author = "hunter"
    public static let preview = PreviewHint(azimuth: 30, elevation: 6, distance: 1.0)

    /// Overall height (m).
    public var height: Float = 3.0
    /// Shaft width and projection from the wall (m).
    public var shaftWidth: Float = 0.4
    public var shaftDepth: Float = 0.08
    /// Number of flutes on the face (0 = plain).
    public var flutes = 7
    /// Rain streak and soot strength.
    public var weathering: Float = 0.45
    public var material: MaterialKey = "stone.limestone"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let w = shaftWidth, d = shaftDepth, H = height
        // Base: plinth, torus, fillet, scotia, fillet, small torus, apophyge to the shaft face.
        var b = ArchProfile()
        b.step(d + 0.06); b.fillet(0.12)
        b.torus(0.03); b.step(-0.02); b.fillet(0.008)
        b.scotia(0.03, depth: 0.012); b.fillet(0.006); b.step(0.006)
        b.torus(0.018)
        b.step(-(b.end.x - d - 0.008)); b.cavetto(0.02, -0.008)
        let baseTop = b.end.y
        m.add(ArchTrimKit.returnedRun(b, length: w - 2 * d, material: material, span: 0.1))
        // Capital: astragal, necking, echinus, abacus.
        var c = ArchProfile()
        c.step(d); c.bead(0.012); c.step(-0.004); c.fillet(0.13)
        c.step(0.012); c.fillet(0.01); c.ovolo(0.05, 0.045)
        c.fillet(0.075)
        c.step(0.008); c.cymaReversa(0.02, 0.012)
        let capH = c.end.y
        m.add(ArchTrimKit.returnedRun(c, length: w - 2 * d, material: material, span: 0.1), Xform(translation: V3(0, H - capH, 0)))
        // Shaft: profile across the face (y = across, x = projection) swept up the height.
        let y0 = baseTop - 0.004, y1 = H - capH + 0.004
        var s = ArchProfile()
        s.step(d)
        if flutes > 0 {
            let fillet: Float = 0.018
            let fw = (w - fillet * Float(flutes + 1)) / Float(flutes)
            s.fillet(fillet)
            for _ in 0..<flutes { s.scotia(fw, depth: min(0.014, fw * 0.4), segments: 6); s.fillet(fillet) }
        } else {
            s.fillet(w)
        }
        // Flute ends: sweep the fluted face, then cap with plain bands at top and bottom.
        let band: Float = 0.06
        let shaft = ArchTrimKit.sweep(s, from: { _ in -(y1 - band) }, to: { _ in -(y0 + band) }, material: material, spans: 10)
        m.add(shaft, Xform(translation: V3(-w / 2, 0, 0), rotation: simd_quatf(angle: -.pi / 2, axis: V3(0, 0, 1))))
        var plain = ArchProfile(); plain.step(d); plain.fillet(w)
        for (a, z) in [(y0, y0 + band), (y1 - band, y1)] {
            let p = ArchTrimKit.sweep(plain, from: { _ in -z }, to: { _ in -a }, material: material)
            m.add(p, Xform(translation: V3(-w / 2, 0, 0), rotation: simd_quatf(angle: -.pi / 2, axis: V3(0, 0, 1))))
        }
        ArchTrimKit.weather(&m, seed: seed, amount: weathering)
        groundAO(&m, height: 0.3, floor: 0.6)
        return LODModel(ArchTrimKit.ground(m))
    }
}
