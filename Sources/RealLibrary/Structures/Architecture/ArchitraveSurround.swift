import simd
import Foundation

/// Window architrave surround: a two-fascia molded band mitered around a rectangular opening, standing
/// on a projecting sill with a drip groove and two corbel blocks. Back on the wall plane; base (bottom of
/// the sill blocks) at y = 0, opening centered on X.
public struct ArchitraveSurround: RealAsset {
    public static let id = "architrave-surround"
    public static let summary = "Window architrave surround, 0.9 x 1.5 m opening: molded band with crossette ears and a projecting sill on blocks."
    public static let tags = ["structure", "architecture", "facade", "trim", "stone"]
    public static let budget = 14_000
    public static let author = "hunter"
    public static let preview = PreviewHint(azimuth: 25, elevation: 6, distance: 1.0)

    /// Clear opening width and height (m).
    public var openingWidth: Float = 0.9
    public var openingHeight: Float = 1.5
    /// Architrave band width (m).
    public var bandWidth: Float = 0.15
    /// Band projection from the wall (m).
    public var bandDepth: Float = 0.05
    /// Sill projection and height (m).
    public var sillDepth: Float = 0.11
    public var sillHeight: Float = 0.07
    /// Rain streak and soot strength.
    public var weathering: Float = 0.5
    /// Crossette ears: the head runs past the jambs by `ear` and drops `earDrop` (0 = plain miters).
    public var ear: Float = 0.05
    public var earDrop: Float = 0.07
    /// Dark reveal panel filling the opening (set "" to leave the opening empty).
    public var revealMaterial: MaterialKey = "paint.wall:2E2D2A"
    public var material: MaterialKey = "stone.cast-stone"
    public init() {}

    /// Band profile: y = distance outward from the opening edge, x = projection.
    func bandProfile() -> ArchProfile {
        let b = bandWidth, d = bandDepth
        var p = ArchProfile()
        p.step(d * 0.45); p.fillet(b * 0.04)        // inner bead seat
        p.bead(0.007)
        p.fillet(b * 0.3)                           // first fascia
        p.step(d * 0.15); p.fillet(b * 0.33)        // second fascia
        p.cymaReversa(b * 0.16, d * 0.32)
        p.fillet(b * 0.04)
        p.to(V2(p.end.x, b))
        p.step(-p.end.x * 0.2)
        return p
    }

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let ow = openingWidth / 2, oh = openingHeight, bw = bandWidth
        let blockH: Float = 0.08
        let sillTop = blockH + sillHeight
        let y0 = sillTop, y1 = sillTop + oh
        let prof = bandProfile()
        // Head: along X, profile up.
        let eared = ear > 0
        let headEnd: (V2) -> Float = { p in eared ? ow + bw + ear : ow + p.y }
        m.add(ArchTrimKit.sweep(prof, from: { p in -headEnd(p) }, to: { p in headEnd(p) }, material: material, spans: 16),
              Xform(translation: V3(0, y1, 0)))
        if eared {
            // Ear drops: short returns of the band below the head, outside the jambs.
            let drop = ArchTrimKit.sweep(prof.scaled(V2(1, ear / bw)), from: { _ in y1 - earDrop }, to: { _ in y1 + 0.002 }, material: material)
            m.add(drop, Xform(translation: V3(-ow - bw, 0, 0), rotation: simd_quatf(angle: .pi / 2, axis: V3(0, 0, 1))))
            let dropR = ArchTrimKit.sweep(prof.scaled(V2(1, ear / bw)), from: { _ in -(y1 + 0.002) }, to: { _ in -(y1 - earDrop) }, material: material)
            m.add(dropR, Xform(translation: V3(ow + bw, 0, 0), rotation: simd_quatf(angle: -.pi / 2, axis: V3(0, 0, 1))))
        }
        // Jambs: local X becomes world Y; local Y points away from the opening.
        let jambTop: (V2) -> Float = { p in eared ? y1 : y1 + p.y }
        let left = ArchTrimKit.sweep(prof, from: { _ in y0 }, to: jambTop, material: material, spans: 20)
        m.add(left, Xform(translation: V3(-ow, 0, 0), rotation: simd_quatf(angle: .pi / 2, axis: V3(0, 0, 1))))
        let right = ArchTrimKit.sweep(prof, from: { p in -jambTop(p) }, to: { _ in -y0 }, material: material, spans: 20)
        m.add(right, Xform(translation: V3(ow, 0, 0), rotation: simd_quatf(angle: -.pi / 2, axis: V3(0, 0, 1))))
        // Sill: drip groove under the nose, weathered top falling outward.
        var sp = ArchProfile()
        sp.step(sillDepth - 0.025); sp.line(0, 0.008); sp.step(0.008); sp.line(0, -0.008); sp.step(0.017)
        sp.fillet(sillHeight - 0.015)
        sp.to(V2(0, sillHeight))
        let sillLen = 2 * (ow + bw) + 0.1
        m.add(ArchTrimKit.sweep(sp, length: sillLen, material: material), Xform(translation: V3(0, blockH, 0)))
        // Corbel blocks under the sill ends.
        for s in [Float(-1), 1] {
            m.add(Prim.roundedBox(V3(bw * 0.9, blockH, sillDepth * 0.7), radius: 0.005, bevelSegments: 2, material: material),
                  Xform(translation: V3(s * (ow + bw / 2), blockH / 2, sillDepth * 0.35)))
        }
        if !revealMaterial.isEmpty {
            m.add(Prim.roundedBox(V3(2 * ow + 0.02, oh + 0.02, 0.01), radius: 0.002, bevelSegments: 1, material: revealMaterial),
                  Xform(translation: V3(0, y0 + oh / 2, -0.006)))
        }
        ArchTrimKit.weather(&m, seed: seed, amount: weathering)
        return LODModel(ArchTrimKit.ground(m))
    }
}
