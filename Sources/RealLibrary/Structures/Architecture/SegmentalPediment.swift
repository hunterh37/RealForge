import simd
import Foundation

/// Segmental pediment: horizontal cornice with returns under a molded segmental arc cornice framing a
/// flat tympanum, the arc ends standing on plinth blocks. Back on the wall plane; base at y = 0.
public struct SegmentalPediment: RealAsset {
    public static let id = "segmental-pediment"
    public static let summary = "Segmental pediment, 2.2 m: horizontal cornice under a molded segmental arc cornice framing a tympanum."
    public static let tags = ["structure", "architecture", "facade", "trim", "stone"]
    public static let budget = 12_000
    public static let author = "hunter"
    public static let preview = PreviewHint(azimuth: 25, elevation: 4, distance: 1.05)

    /// Width of the horizontal cornice (m).
    public var width: Float = 2.0
    /// Rise of the arc above the cornice (m).
    public var rise: Float = 0.3
    /// Overall cornice scale (1 = 0.17 m tall).
    public var scale: Float = 1
    /// Rain streak and soot strength.
    public var weathering: Float = 0.5
    public var material: MaterialKey = "stone.limestone"
    public var tympanumMaterial: MaterialKey = "stone.limestone:CFC5AF"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let k = scale, W = width
        let prof = TriangularPediment.cornice().scaled(k * 0.85)
        let ch = prof.maxY
        m.add(ArchTrimKit.returnedRun(prof, length: W, material: material, span: 0.15))
        // Arc through (-c, 0), (c, 0), (0, rise) above the cornice top.
        let c = W / 2 - 0.08 * k
        let R = (c * c + rise * rise) / (2 * rise), cy = rise - R
        let a0 = asin(c / R)
        let n = 32
        let path: [V2] = (0...n).map { i in
            let x = -c + 2 * c * Float(i) / Float(n)
            return V2(x, cy + sqrt(R * R - x * x))
        }
        m.add(ArchTrimKit.sweep(prof, along: path, material: material), Xform(translation: V3(0, ch, 0)))
        // Tympanum: circular segment set back.
        var seg: [V2] = []
        for i in 0...24 { let a = -a0 + 2 * a0 * Float(i) / 24; seg.append(V2((R - 0.01) * sin(a), cy + (R - 0.01) * cos(a))) }
        seg = Shape2D.deduped(seg.reversed())
        m.add(Prim.extrude(seg, depth: 0.03 * k, bevel: 0.003, bevelSegments: 1, material: tympanumMaterial),
              Xform(translation: V3(0, ch, 0.015 * k)))
        // Plinths under the arc springing.
        for s in [Float(-1), 1] {
            m.add(Prim.roundedBox(V3(0.16 * k, 0.05 * k, 0.15 * k), radius: 0.005, bevelSegments: 2, material: material),
                  Xform(translation: V3(s * c, ch + 0.02 * k, 0.075 * k)))
        }
        ArchTrimKit.weather(&m, seed: seed, amount: weathering)
        return LODModel(ArchTrimKit.ground(m))
    }
}
