import simd
import Foundation

/// Dentil course: backing fascia with square dentil blocks under an ovolo cap. Back face on the wall
/// plane, run along X; tile every `length`, miter the ends for outside corners.
public struct DentilCourse: RealAsset {
    public static let id = "dentil-course"
    public static let summary = "Dentil course, 1.2 m run: square dentil blocks between a backing fascia and an ovolo cap; tiles along X."
    public static let tags = ["structure", "architecture", "facade", "trim", "stone"]
    public static let budget = 9_000
    public static let author = "hunter"
    public static let preview = PreviewHint(azimuth: 30, elevation: -10, distance: 0.9)

    /// Run length along X (m).
    public var length: Float = 1.2
    /// Dentil block height (m); the course is about 0.08 m taller.
    public var dentilHeight: Float = 0.092
    /// Dentil projection from the backing fascia (m).
    public var dentilDepth: Float = 0.06
    /// Dentil centers along X (m).
    public var spacing: Float = 0.09
    /// Dentil width as a fraction of `spacing`.
    public var dentilFraction: Float = 0.66
    public var miterStart = false
    public var miterEnd = false
    /// Rain streak and soot strength (0 = freshly cut).
    public var weathering: Float = 0.5
    public var material: MaterialKey = "stone.limestone"
    /// Dentils (sheltered under the cap).
    public var dentilMaterial: MaterialKey = "stone.limestone-sooted"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var p = ArchProfile()
        p.step(0.03); p.fillet(0.016)
        p.step(-0.015)
        let y0 = p.end.y, x0 = p.end.x
        p.fillet(dentilHeight + 0.004)
        p.step(dentilDepth); p.ovolo(0.035, 0.03); p.fillet(0.012)
        var m = Model(name: Self.id)
        m.add(ArchTrimKit.sweep(p, length: length, material: material, miterStart: miterStart, miterEnd: miterEnd))
        let n = max(1, Int((length / spacing).rounded())), pitch = length / Float(n)
        for i in 0..<n {
            var r = rng.fork(i)
            let sz = V3(pitch * dentilFraction + r.float(-0.001...0.001), dentilHeight, dentilDepth - 0.002)
            m.add(Prim.roundedBox(sz, radius: 0.003, bevelSegments: 1, material: dentilMaterial),
                  Xform(translation: V3(-length / 2 + pitch * (Float(i) + 0.5), y0 + 0.002 + dentilHeight / 2, x0 + sz.z / 2)))
        }
        ArchTrimKit.weather(&m, seed: seed, amount: weathering)
        return LODModel(ArchTrimKit.ground(m))
    }
}
