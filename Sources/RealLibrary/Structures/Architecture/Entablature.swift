import simd
import Foundation

/// Ionic entablature: three-fascia architrave with a cyma cap, plain frieze, dentil course with an egg-and-dart ovolo, bed mold,
/// corona over a soffit with a drip, and a cyma recta crown. Back face on the wall plane, run along X;
/// tile every `length`, miter the ends for outside corners.
public struct Entablature: RealAsset {
    public static let id = "entablature"
    public static let summary = "Ionic entablature, 1.2 m run: three-fascia architrave, plain frieze, dentil cornice, corona and cyma crown; tiles along X."
    public static let tags = ["structure", "architecture", "facade", "trim", "stone"]
    public static let budget = 14_000
    public static let author = "hunter"
    public static let preview = PreviewHint(azimuth: 30, elevation: -12, distance: 1.05)

    /// Run length along X (m).
    public var length: Float = 1.2
    /// Overall scale (1 = 0.85 m tall).
    public var scale: Float = 1
    /// Frieze height before scaling (m).
    public var friezeHeight: Float = 0.24
    /// Dentil centers along X (m, before scaling).
    public var dentilSpacing: Float = 0.085
    public var miterStart = false
    public var miterEnd = false
    /// Rain streak and soot strength (0 = freshly cut).
    public var weathering: Float = 0.5
    public var material: MaterialKey = "stone.limestone"
    /// Dentils (sheltered under the corona).
    public var dentilMaterial: MaterialKey = "stone.limestone-sooted"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var p = ArchProfile()
        // Architrave: three fasciae stepping out, each crowned by a small bead.
        p.step(0.02); p.fillet(0.07)
        p.step(0.006); p.bead(0.006); p.step(0.002); p.fillet(0.075)
        p.step(0.006); p.bead(0.006); p.step(0.002); p.fillet(0.085)
        p.cymaReversa(0.035, 0.03); p.fillet(0.012)
        // Frieze, set back.
        p.step(-(p.end.x - 0.03)); p.fillet(friezeHeight)
        // Bed mold and dentils.
        p.cymaReversa(0.03, 0.022); p.fillet(0.006)
        let dy = p.end.y, dx = p.end.x
        p.fillet(0.065)
        p.step(0.05)
        let ey = p.end.y, ex = p.end.x
        p.ovolo(0.026, 0.024); p.fillet(0.008)
        // Corona with soffit and drip lip, then crown.
        p.step(0.17); p.fillet(0.008); p.step(-0.006); p.fillet(0.08)
        p.step(0.01); p.fillet(0.01)
        p.cymaRecta(0.065, 0.055); p.fillet(0.016)
        let prof = p.scaled(scale)
        var m = Model(name: Self.id)
        m.add(ArchTrimKit.sweep(prof, length: length, material: material, miterStart: miterStart, miterEnd: miterEnd))
        let k = scale
        let n = max(1, Int((length / (dentilSpacing * k)).rounded())), pitch = length / Float(n)
        for i in 0..<n {
            var r = rng.fork(i)
            let sz = V3(pitch * 0.64 + r.float(-0.001...0.001), 0.063 * k, 0.048 * k)
            m.add(Prim.roundedBox(sz, radius: 0.003 * k, bevelSegments: 1, material: dentilMaterial),
                  Xform(translation: V3(-length / 2 + pitch * (Float(i) + 0.5), (dy + 0.001 + 0.0315) * k, (dx + 0.024) * k)))
        }
        // Egg-and-dart on the ovolo over the dentils.
        m.add(ArchTrimKit.eggAndDart(length: length, pitch: 0.05 * k, size: V3(0.036, 0.028, 0.022) * k,
                                     at: V2((ey + 0.014) * k, (ex + 0.017) * k), material: material))
        ArchTrimKit.weather(&m, seed: seed, amount: weathering)
        return LODModel(ArchTrimKit.ground(m))
    }
}
