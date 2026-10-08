import simd
import Foundation

/// Triangular pediment: horizontal cornice with returns, two raking cornices mitered at the apex and
/// cut plumb at the eaves, a recessed tympanum and acroterion plinths. Back on the wall plane; base
/// (cornice soffit) at y = 0.
public struct TriangularPediment: RealAsset {
    public static let id = "triangular-pediment"
    public static let summary = "Triangular pediment, 3 m: horizontal cornice, two raking cornices mitered at the apex over a recessed tympanum."
    public static let tags = ["structure", "architecture", "facade", "trim", "stone"]
    public static let budget = 12_000
    public static let author = "hunter"
    public static let preview = PreviewHint(azimuth: 25, elevation: 4, distance: 1.05)

    /// Width of the horizontal cornice (m).
    public var width: Float = 2.8
    /// Roof pitch of the raking cornices (degrees).
    public var pitch: Float = 15
    /// Overall cornice scale (1 = 0.2 m tall).
    public var scale: Float = 1
    /// Acroterion plinths at the apex and eaves.
    public var acroteria = true
    /// Rain streak and soot strength.
    public var weathering: Float = 0.5
    public var material: MaterialKey = "stone.limestone"
    public var tympanumMaterial: MaterialKey = "stone.limestone:CFC5AF"
    public init() {}

    static func cornice() -> ArchProfile {
        var p = ArchProfile()
        p.step(0.03); p.fillet(0.03)
        p.cymaReversa(0.03, 0.03)
        p.step(0.08); p.fillet(0.006); p.step(-0.004); p.fillet(0.06)
        p.step(0.008); p.fillet(0.008)
        p.cymaRecta(0.05, 0.045); p.fillet(0.012)
        return p
    }

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let k = scale, W = width, h = W / 2
        let prof = Self.cornice().scaled(k)
        let ch = prof.maxY
        m.add(ArchTrimKit.returnedRun(prof, length: W, material: material, span: 0.15))
        // Raking cornices: start on the cornice top at the eave, cut plumb at x = -h, mitered at x = 0.
        let a = pitch * .pi / 180, ca = cos(a), sa = sin(a)
        let rake = prof
        let left = ArchTrimKit.sweep(rake, from: { p in p.y * sa / ca }, to: { p in (h + p.y * sa) / ca }, material: material, spans: 10)
        m.add(left, Xform(translation: V3(-h, ch, 0), rotation: simd_quatf(angle: a, axis: V3(0, 0, 1))))
        let right = ArchTrimKit.sweep(rake, from: { p in -(h + p.y * sa) / ca }, to: { p in -p.y * sa / ca }, material: material, spans: 10)
        m.add(right, Xform(translation: V3(h, ch, 0), rotation: simd_quatf(angle: -a, axis: V3(0, 0, 1))))
        // Tympanum, set back from the cornice faces.
        let ty = h * tan(a)
        let tri: [V2] = [V2(-h + 0.02, 0), V2(h - 0.02, 0), V2(0, ty - 0.02)]
        m.add(Prim.extrude(tri, depth: 0.03 * k, bevel: 0.003, bevelSegments: 1, material: tympanumMaterial),
              Xform(translation: V3(0, ch, 0.015 * k)))
        if acroteria {
            let top = ch + ty + prof.maxY / ca
            let pl = Prim.roundedBox(V3(0.2 * k, 0.12 * k, 0.16 * k), radius: 0.006, bevelSegments: 2, material: material)
            m.add(pl, Xform(translation: V3(0, top - 0.02 * k + 0.06 * k, 0.08 * k)))
            for s in [Float(-1), 1] {
                m.add(pl, Xform(translation: V3(s * (h - 0.1 * k), ch + prof.maxY / ca + 0.04 * k, 0.08 * k)))
            }
        }
        ArchTrimKit.weather(&m, seed: seed, amount: weathering)
        return LODModel(ArchTrimKit.ground(m))
    }
}
