import simd
import Foundation

/// MUTCD R1-1 stop sign: a 75 cm (30 in) aluminum octagon with retroreflective red sheeting, white
/// border and STOP legend, bolted to a perforated square galvanized post. The sheeting fades a little
/// per seed and the plate leans a degree or two on its post.
public struct StopSign: RealAsset {
    public static let id = "stop-sign"
    public static let summary = "Stop sign: 75 cm red octagon with white border and STOP lettering on a galvanized square post."
    public static let tags = ["prop", "city", "street", "urban", "outdoor", "metal", "sign"]
    public static let budget = 3000
    public static let author = "realityhd"
    public static let preview = PreviewHint(azimuth: 25, elevation: 8, distance: 1.1)

    /// Octagon width across flats (m).
    public var width: Float = 0.762
    /// Height of the sign top above the ground (m).
    public var height: Float = 2.9
    /// Post side (m).
    public var postSide: Float = 0.05
    /// Legend.
    public var legend = "STOP"
    /// Sheeting faded toward pink with sun (0 new ... 1 badly faded).
    public var fade: Float = 0.25
    /// Materials.
    public var post: MaterialKey = "metal.galvanized"
    public var bolt: MaterialKey = "metal.steel"
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var rng = SeededRNG(seed: seed)
        var m = Model(name: Self.id)
        let r = width / 2 / cos(Float.pi / 8)
        let oct = Shape2D.polygon(sides: 8, radius: r, rotation: .pi / 8)
        let cy = height - width / 2, zFace = postSide / 2 + 0.004
        let f = min(1, max(0, fade + rng.float(-0.1...0.1)))
        let red = String(format: "%02X%02X%02X", Int(150 + 50 * f), Int(8 + 40 * f), Int(10 + 40 * f))
        citySquarePost(&m, side: postSide, height: cy + 0.2, material: post)
        let lean = simd_quatf(angle: rng.float(-0.02...0.02), axis: V3(0, 0, 1))
        let x = Xform(translation: V3(0, cy, zFace), rotation: lean)
        let legendH = width * 0.333
        citySignPlate(&m, outline: oct, x: x, border: width * 0.025, face: "sign.red-worn:\(red)",
                      text: [(legend, V2(0, 0), legendH, 0.56)])
        // Two carriage bolts through the plate into the post.
        for by in [cy + width * 0.36, cy - width * 0.36] {
            m.add(Prim.cylinder(radius: 0.008, height: 0.004, bevel: 0.0015, segments: 10, material: bolt),
                  Xform(translation: V3(0, by, zFace + 0.0015), rotation: simd_quatf(degrees: 90, axis: V3(1, 0, 0))))
        }
        groundAO(&m, height: 0.2, floor: 0.6)
        return LODModel(m)
    }
}
