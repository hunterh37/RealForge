import simd
import Foundation

/// String (belt) course: projecting band with a drip groove in the soffit, fascia, cyma reversa and a
/// sloped weathered top that sheds water. Back face on the wall plane, run along X; tile every `length`.
public struct StringCourse: RealAsset {
    public static let id = "string-course"
    public static let summary = "String course, 1.2 m run: fascia, cyma reversa and sloped weathered top with a drip groove; tiles along X."
    public static let tags = ["structure", "architecture", "facade", "trim", "stone"]
    public static let budget = 1_000
    public static let author = "hunter"
    public static let preview = PreviewHint(azimuth: 30, elevation: 10, distance: 0.9)

    /// Run length along X (m).
    public var length: Float = 1.2
    /// Fascia height (m).
    public var fasciaHeight: Float = 0.07
    /// Projection of the fascia from the wall (m).
    public var projection: Float = 0.08
    /// Rise of the weathered top from front to wall (m).
    public var weatherRise: Float = 0.035
    /// Rain streak and soot strength (0 = freshly cut).
    public var weathering: Float = 0.55
    /// Length of each stone (m); joints fall between stones.
    public var stoneLength: Float = 0.6
    public var miterStart = false
    public var miterEnd = false
    public var material: MaterialKey = "stone.sandstone"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var p = ArchProfile()
        p.step(projection - 0.025)
        p.line(0, 0.008); p.step(0.008); p.line(0, -0.008)   // drip groove
        p.step(0.013); p.line(0.004, 0.004)
        p.fillet(fasciaHeight - 0.008); p.line(-0.003, 0.004)
        p.cymaReversa(0.04, 0.022); p.fillet(0.014)
        p.line(-0.004, 0.003)
        p.to(V2(0, p.end.y + weatherRise))
        var m = Model(name: Self.id)
        // Stones of `stoneLength` with fine joints; each a slightly different tone.
        let n = max(1, Int((length / stoneLength).rounded())), pitch = length / Float(n)
        var rng = SeededRNG(seed: seed)
        for i in 0..<n {
            var r = rng.fork(i)
            let a = -length / 2 + pitch * Float(i), b = a + pitch
            let g0: Float = i == 0 ? 0 : 0.003, g1: Float = i == n - 1 ? 0 : 0.003
            let ms = miterStart && i == 0, me = miterEnd && i == n - 1
            m.add(ArchTrimKit.sweep(p, from: { q in ms ? a - q.x : a + g0 }, to: { q in me ? b + q.x : b - g1 },
                                    material: material + r.pick(["", ":C4A47A", ":BE9C70", ":CCAE86"]), spans: 1))
        }
        ArchTrimKit.weather(&m, seed: seed, amount: weathering)
        return LODModel(ArchTrimKit.ground(m))
    }
}
