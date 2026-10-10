import simd
import Foundation

/// Skatepark quarter pipe, 1.2 m high and 2.4 m wide: plywood transition on a radius of 1.2 m, flat deck, steel coping.
public struct SkateQuarterPipe: RealAsset {
    public static let id = "skate-quarter-pipe"
    public static let summary = "Skatepark quarter pipe, 1.2 m: concrete transition on a 1.2 m radius, flat deck and round steel coping."
    public static let tags = ["prop", "park", "outdoor", "sports", "concrete"]
    public static let budget = 500
    public static let author = "hunterh37"

    /// Transition radius and height in meters.
    public var radius: Float = 1.2
    /// Ramp width in meters.
    public var width: Float = 2.4
    public init() {}

    public func build(seed: UInt64) -> LODModel {
        var m = Model(name: Self.id)
        let R = radius, deck: Float = 0.6
        var pts: [V2] = []
        for i in 0...20 { let t = Float(i) / 20 * .pi / 2; pts.append(V2(R * sin(t), R * (1 - cos(t)))) }
        pts.append(V2(R + deck, R)); pts.append(V2(R + deck, 0)); pts.append(V2(R * 0.5, 0))
        m.add(Prim.extrude(pts, depth: width, bevel: 0.006, bevelSegments: 1, material: "concrete.smooth"))
        m.add(Prim.tube([V3(R - 0.01, R, -width / 2), V3(R - 0.01, R, width / 2)], radii: [0.025, 0.025], sides: 14, seamTile: 0.2, material: "metal.steel"))
        bx(&m, V3(0.04, 0.012, width), V3(R + deck - 0.02, R + 0.006, 0), "metal.galvanized", r: 0.003)
        return K.finish(&m, ao: 0.2)
    }
}
