import simd
import Foundation

/// Asphalt speed hump, 3.0 m across the lane and 0.9 m long in travel: 0.09 m crown with yellow chevron paint.
public struct SpeedBump: RealAsset {
    public static let id = "speed-bump"
    public static let summary = "Asphalt speed hump, 3 m wide and 0.9 m long: 9 cm rounded crown with yellow chevron stripes."
    public static let tags = ["prop", "road", "street", "barrier"]
    public static let budget = 800
    public static let author = "hunterh37"

    /// Crown height in meters.
    public var crown: Float = 0.09
    /// Lane width in meters.
    public var laneWidth: Float = 3.0
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        var pts: [V2] = [V2(-0.45, 0)]
        for i in 0...10 { let t = Float(i) / 10; pts.append(V2(-0.45 + 0.9 * t, crown * sin(t * .pi))) }
        pts.append(V2(0.45, 0))
        m.add(Prim.extrude(pts, depth: laneWidth, bevel: 0.004, bevelSegments: 1, material: "asphalt.road"))
        let stripes = Int(laneWidth / 0.3)
        for i in 0..<stripes where i % 2 == 0 {
            let z = -laneWidth / 2 + (Float(i) + 0.5) * laneWidth / Float(stripes)
            m.add(Prim.roundedBox(V3(0.5, 0.004, laneWidth / Float(stripes)), radius: 0.001, bevelSegments: 1, material: "plastic.yellow"), Xform(translation: V3(0, crown + 0.0015, z)))
        }
        return K.finish(&m, ao: 0.05)
    }
}
